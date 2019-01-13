pragma solidity ^0.4.24;


contract Taxi {
    
/* EXPLANATIONS (Hocam lutfen okuyun)
- Please use 0.4.25+commit.59dbf8f1.Emscripten.clang for compiling this contract.
- If this error '0x0 Transaction mined but execution failed' occurs, please change Gas Limit to '30000000000'.
I do not know the reason of this error but with this changement it fixes itself.
- There is one mananger who set the second address of Account part in the left top corner which is (0x14723a09acff6d2a60dcdf7aa4aff308fddc160c). 
- There is one owner who deploys the contract and can set manager with setManager function by giving address as a parameter.
- There is one car dealer and one car driver (taxi driver) manager can set them by giving address as a parameter to their set functions.
- In this contract purchase proposal and car proposal are only one. If car dealer wants to change proposes again and old proposal will be deleted.
- All fees are initiated in the constructor.
- In the proposal functions howManyDaysIsItValid parameter means that proposal validity continues by how many days.
For example, if this parameter equals to 10, which means that proposal will be valid for the next ten days after the proposal function is called.
So, if function called at the 14/01/2019, proposal will be valid through 24/01/2019.
- Dates handled with 'now' feature and timestamps, all dates converted to timestamps, date validations made with these timestamps.
- In the sellCar function car dealer must look the purchase proposal (publicly visible) and gave the exact same price in the proposal,
otherwise process will be failed.
- If there is an error occurred, with 'require' feature the reason of failure is shown in the console.
- In this contract one month assumed to 30 days.
- While pating the dividens, dividend will be calculated with this formula: (contractBalance - driverSalary(One Month) - carExpenses) / participantCount
- Other helper explanations are on the top of functions.
*/
    // Contract's special addresses.
    address owner;
    address manager;
    address carDealer;
    address carDriver;
    
    address[] participants; // Used for keep tracking of participants.
    mapping(address => bool) participantControlMapping; // Used for participant modifier is it true then only participant modifier will work.
    mapping(address => bool) approvalStateControlMapping; // Used for keep tracking of participants' votes to purchase proposal for a car.

    uint public ownedCar; // Contract's car ID, public everyone can call and see.
    uint maxParticipationNumber; 
    uint participationCounter; 
    uint approvalState;
    
    uint digitCountChecker = 10000000000000000000000000000000; // 32 digit number, used for validation of car ID.
    
    // These are used for day to timestamp convertions.
    uint incrementAmountToTimestampFor180days; // 6 months
    uint incrementAmountToTimestampFor30days;   // 1 month
    
    // Fees 
    uint participationFee;
    uint taxiFee;
    uint carExpensesFee;
    uint driverSalaryFee;
    
    // Timestamps for controlling contract processes.
    uint lastPayDriverSalaryDate;
    uint lastPayDealerExpenseDate;
    uint lastPayDividendDate;
    
    // Checkers
    bool checkIsDriverSalaryPaid;
    bool checkIsExpensesFeePaid;
    bool checkIsCarProposalExist;
    bool checkIsPurchaseCarProposalExist;
    bool checkIsCarExist;
    bool checkIsDriverExist;
    bool checkIsDealerExist;


    // Initiate the contract variables and set the manager at the second address which is 0x14723a09acff6d2a60dcdf7aa4aff308fddc160c.
    constructor() public {
        owner = msg.sender;
        
        checkIsExpensesFeePaid = false;
        checkIsDriverSalaryPaid = false;
        checkIsPurchaseCarProposalExist = false;
        checkIsCarProposalExist = false;
        checkIsCarExist = false;
        checkIsDealerExist = false;
        checkIsDriverExist = false;
        
        maxParticipationNumber = 100;
        participationCounter = 0;
        approvalState = 0;
        
        incrementAmountToTimestampFor30days = 60 * 60 * 24 * 30; // 1 minute * 1 hour * 24 hours * 30 days in the unit of seconds
        incrementAmountToTimestampFor180days = 60 * 60 * 24 * 180; // 1 minute * 1 hour * 24 hours * 180 days in the unit of seconds 
        
        taxiFee = 1 ether;
        participationFee = 100 ether;
        carExpensesFee = 10 ether;
        driverSalaryFee = 10 ether;
        
        setManager(0x14723a09acff6d2a60dcdf7aa4aff308fddc160c);
    }
    
    // Purchase proposal struct
     struct PurchasePropose {
        uint carID;
        uint priceInEtherUnit;
        uint validThroughTimestamp;
    }
    
    // Car proposal struct
    struct ProposedCar {
        uint carID;
        uint priceInEtherUnit;
        uint validThroughTimestamp;
    }
    
    // Public objects of proposals, everyone can see them.
    PurchasePropose public purchaseProposedCar;
    ProposedCar public proposedCar;
    
    // Modifiers
    modifier onlyParticipants {
        require(participantControlMapping[msg.sender], 'This function only called by participants');
        _;
    }
    
    modifier onlyCarDealer {
        require(msg.sender == carDealer, 'This function only called by car dealer');
        _;
    }

    modifier onlyOwner {
        require(msg.sender == owner, 'This function only called by owner');
        _;
    }
    
    modifier onlyManager {
        require(msg.sender == manager, 'This function only called by manager');
        _;
    }
    
    modifier onlyDriver {
        require(msg.sender == carDriver, 'This function only called by taxi driver');
        _;
    }
    
    // Mapping of address and balances used for pending salaries, dividends etc.
    mapping(address => uint) balances;
    
    // Join function of investment any user can come and join if he/she has 100 ether.
    function joinTaxiInvestment() public payable {
        require(msg.value == participationFee, 'Participation fee must be 100 ether');
        require(participationCounter != maxParticipationNumber, 'There is no participant allowed due to bound of hundred participant rule');
        require(!participantControlMapping[msg.sender], 'User is already a participant');
        
        participants.push(tx.origin);
        participantControlMapping[tx.origin] = true;
        participationCounter += 1;
    }
    
    // If there is a sell proposal participants can approve the proposal.
    function approveSellProposal() onlyParticipants public {
        require(checkIsPurchaseCarProposalExist, "There is no purchase car proposal");
        require(!approvalStateControlMapping[msg.sender], 'Particant approved before');
        
        approvalState += 1;
        approvalStateControlMapping[msg.sender] = true;
    }
    
    // If there is a purchase propose and consensus is provided by participants ownedCar selled to car dealer and contract balance is increased.
    // Car dealer must pay the price that he/she set before otherwise system gives an error.
    function sellCar() payable onlyCarDealer public {
        require(now < purchaseProposedCar.validThroughTimestamp, 'Transaction failed due to valid timestamp of proposal is exceeded');
        
        uint amount = purchaseProposedCar.priceInEtherUnit * 1 ether;
        require(msg.value == amount, 'You must pay the exact car price that set in the purchase car proposal'); 
        require(approvalState > (participationCounter/2), 'Transaction failed due to consensus is not provided'); 
        ownedCar = 0;
        checkIsCarExist = false;
        checkIsPurchaseCarProposalExist = false;
        approvalState = 0;
        delete purchaseProposedCar;
    }
    
    // Car dealer makes a purchase propose if there is a car (ownedCar) exist in the contract. 
    // Proposal price must be given in ether unit, for example (50), this means 50 ether in the proposal. No need to write '50 ether' 
    // This is public and all participants can see purchase propose.
    function purchasePropose(uint _priceInEtherUnit, uint _howManyDaysIsItValid) onlyCarDealer public {
        require(checkIsCarExist, 'There is no car in the contract');
        require(_priceInEtherUnit > 0, 'Price must be greater than zero');
        purchaseProposedCar.carID = ownedCar;
        purchaseProposedCar.priceInEtherUnit = _priceInEtherUnit;
        
        uint convertDayToTimestamp = _howManyDaysIsItValid * 60 * 60 * 24;
        purchaseProposedCar.validThroughTimestamp = now + convertDayToTimestamp;
        
        approvalState = 0;
        checkIsPurchaseCarProposalExist = true;
           
        for(uint index = 0; index < participants.length; index++) {
            approvalStateControlMapping[participants[index]] = false; 
        }
    }
    
    // Car dealer makes a car propose if carID are 32 digits.
    // Proposal price must be given in ether unit, for example (50), this means 50 ether in the proposal. No need to write '50 ether'. 
    // This is public and all participants can see car propose.
    function proposeCar(uint _carID, uint _priceInEtherUnit, uint _howManyDaysIsItValid) onlyCarDealer public{
        require( (_carID/digitCountChecker > 0), 'Car ID must be in the format of 32 digit number');
        require( (_carID/digitCountChecker < 10), 'Car ID must be in the format of 32 digit number');
        require(_priceInEtherUnit > 0, 'Price must be greater than zero');
        proposedCar.carID = _carID;
        proposedCar.priceInEtherUnit = _priceInEtherUnit;
        
        uint convertDayToTimestamp = _howManyDaysIsItValid * 60 * 60 * 24;
        proposedCar.validThroughTimestamp = now + convertDayToTimestamp;
        
        checkIsCarProposalExist = true;
    }
    
    // This function is called for purchasing the car that proposed before by car dealer, only manager can call this function.
    // Also deletes the existing proposal and set the carID.
    function purchaseCar() onlyManager public {
        require(checkIsCarProposalExist, 'There is no car proposal in this contract');
        require(now < proposedCar.validThroughTimestamp, 'Transaction failed due to valid timestamp of proposal is exceeded');
        
        uint carPrice = proposedCar.priceInEtherUnit * 1 ether;
        require(address(this).balance > carPrice, 'Contract balance is not sufficient for this car'); 
        
        carDealer.transfer(carPrice);
        ownedCar = proposedCar.carID;
        checkIsCarProposalExist = false;
        checkIsCarExist = true;
        delete proposedCar;
    }
    
    // This function is used for paying the dividens to participants, only manager can call this function.
    // Dividens calculated with respect to formula and distributed to participant balances.
    // If participant wants to get it he/she can call getDividend function.
    function payDividends() payable onlyManager public {
        require(participants.length > 0, 'There is no participant exist in this contract');
        require(now >= (lastPayDividendDate + incrementAmountToTimestampFor180days), 'This function only be called once in 6 months');
        
        uint dividend = (address(this).balance - carExpensesFee - driverSalaryFee) / participationCounter;
        
        for(uint index = 0; index < participants.length; index++) {
            balances[participants[index]] = (dividend); 
        }
        
        lastPayDividendDate = now;
    }
    
    // This function is used for getting a dividend to participant's account. Only participants can call this function.
    // If dividend exist in the participant's balance, transfer completed to directly participant's account.
    function getDividend() payable onlyParticipants public {
        require (balances[msg.sender] > 0, 'There is no dividend in your account'); 
        uint amount = balances[msg.sender] - 1;
        (msg.sender).transfer(amount);
    }
    
    // This function is used for taxi usage. Anyone can call it.
    // Usage of taxi cost 1 ether, user must be pay this value otherwise process is not completed.
    function getCharge() payable public {
        require (msg.value == taxiFee, 'Usage of taxi cost 1 ether'); 
        balances[msg.sender] -= taxiFee;
    }
    
    // This function is paying salary to taxi driver. Only manager can calls this function.
    // If there is no driver exist in the contract, process will be failed.
    function paySalary() payable onlyManager public {
        require (checkIsDriverExist, 'There is no driver in this contract');
        require (now >= (lastPayDriverSalaryDate + incrementAmountToTimestampFor30days), 'This function only be called once in a month');
        balances[carDriver] = driverSalaryFee;
        lastPayDriverSalaryDate = now;
    }
    
    // If there is salary exist in the car driver's balance, driver can get this money to his/her account.
    function getSalary() payable onlyDriver public {
        require (balances[carDriver] > 0, 'There is no salary in your account');
        carDriver.transfer(balances[carDriver]);
        balances[carDriver] = 0;
    }
    
    // This function is can only called once in 180 days by the manager.
    // Car expenses payed to car dealer.
    // Car has a relationship with dealer so, we do not need to validate car dealer existence.
    function payCarExpenses() payable onlyManager public {
        require(checkIsCarExist, 'There is no car in this contract');
        require (now >= (lastPayDealerExpenseDate + incrementAmountToTimestampFor180days), 'This function only be called once in 6 months');
        carDealer.transfer(carExpensesFee);
        lastPayDealerExpenseDate = now;
    }
    
    // This function sets the contract manager, only called by the owner (the person who deploys contract).
    function setManager(address _address) onlyOwner public {
        manager = _address;
    }
    
    // This function sets the contract car dealer, only called by the manager 
    function setCarDealer(address _address) onlyManager public {
        carDealer = _address;
        checkIsDealerExist = true;
    }
    
    // This function sets the contract taxi driver, only called by the manager
    function setCarDriver(address _address) onlyManager public {
        carDriver = _address;
        checkIsDriverExist = true;
    }
    
    // Helper Function, shows timestamp
    function showNowTimestamp() view public returns(uint) {
        return (now);
    }
    
    // Helper function, shows contract balance
    function showContractBalance() view public returns(uint256) {
        return(address(this).balance);
    }  
}