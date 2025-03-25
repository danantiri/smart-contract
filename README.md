# Danantiri - Blockchain-Based Government Fund Tracking

## Overview

Danantiri is a **blockchain-based** smart contract system designed to **track and manage government funds** with full **transparency and accountability**. Built using **Solidity**, Danantiri utilizes IDRX tokens as the primary payment method.

Danantiri ensures that **all fund transactions are recorded on-chain**, making the system **immutable and verifiable**. Every allocation and withdrawal is **publicly auditable**, preventing misuse and fraud.

## Features

- 📌 **`Create & manage funding programs`** with specific goals and descriptions.  
- ✏️ **`Update program details`** including name, target amount, description, and PIC.  
- 💰 **`Fund allocation`** for registered programs.  
- 💸 **`Send funds`** with IDRX tokens.  
- 🔄 **`Withdraw funds`** securely by designated PIC.  
- 📜 **`Retrieve program status`** (INACTIVE, REGISTERED, or ALLOCATED).  
- 🔍 **`Transparent blockchain record-keeping`** for public verification.  

---

## Smart Contract Details

### 📦 ERC20 Token Integration

The contract interacts with **IDRX ERC20 tokens** for fund transactions.

```solidity
interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}
```

### 📊 Funding Program Structure

```solidity
contract Danantiri {
    enum ProgramStatus { INACTIVE, REGISTERED, ALLOCATED }

    struct Program {
        uint256 id;
        string name;
        uint256 target;
        string desc;
        address pic;
        ProgramStatus status;
        uint256 allocated;
    }

    struct History {
        uint256 timestamp;
        string history;
        uint256 amount;
    }
}
```

Programs are structured to ensure clear tracking with:

- **`Name & Description`** 🏷️ – Provides transparency on program objectives.
- **`Target Funding Amount`** 💲 – Defines the financial goal of the program.
- **`Assigned PIC`** 👤 – Assign responsible individual for the program.
- **`Status (INACTIVE, REGISTERED, ALLOCATED)`** 📡 – Tracks progress and ensures visibility.
- **`Allocated Funds`** 💰 – Displays the amount of funds committed to the program.

### 📜 Danantiri Contract State Variables

Let's define all the necessary variables required for the Danantiri smart contract.

```solidity
address public owner;
Program[] public programs;
uint256 public totalManagedFund;
uint256 public totalAllocated;
IERC20 public idrxToken;
mapping(uint256 => History[]) public programHistories;
```
- **`owner`** 🏛️ – The administrator who has the authority to create and manage programs.
- **`programs`** 📋 – A list of all registered funding programs stored on-chain.
- **`totalAllocated`** 💰 – Tracks the total amount of IDRX tokens that have been distributed to programs.
- **`idrxToken`** 🔗 – The ERC20 token contract used for all transactions within Danantiri.

### 📜 Events

```solidity
event ProgramCreated(uint256 indexed programId, string name, uint256 target, address pic);
event ProgramUpdated(uint256 indexed programId, string name, string desc, address pic);
event FundSent(address indexed sender, uint256 amount);
event FundAllocated(uint256 indexed programId, uint256 amount);
event FundWithdrawn(uint256 indexed programId, address indexed pic, string history, uint256 amount);
```
Events will be used to communicate with external application

### 🔐 Access Control

**Admin-Only Functions**

```solidity
modifier onlyAdmin() {
    require(msg.sender == owner, "Only admin can call this function");
    _;
}
```

**PIC-Restricted Functions**

```solidity
modifier onlyPIC(uint256 _programId) {
    require(msg.sender == programs[_programId].pic, "Not PIC of this program");
    _;
}
```

We will apply this modifier to multiple functions to enforce access control, ensuring that only authorized individuals can execute them.

### 🔐 Constructor

```solidity
constructor(address _tokenAddress) {
    require(_tokenAddress != address(0), "Invalid token address");
    owner = msg.sender;
    idrxToken = IERC20(_tokenAddress);
}
```
Constructor function is used to initialize the state variables of a smart contract

### 🚀 Core Functionalities

#### 1️⃣ Creating a Funding Program

```solidity
function createProgram(
    string calldata _name,
    uint256 _target,
    string calldata _desc,
    address _pic
)
    external
    onlyAdmin
{
    require(bytes(_name).length > 0, "Program name cannot be empty");
    require(_target > 0, "Target must be greater than zero");
    require(bytes(_desc).length > 0, "Description cannot be empty");
    require(_pic != address(0), "PIC address cannot be zero");

    uint256 newId = programs.length;
    Program memory newProgram = Program({
        id: newId,
        name: _name,
        target: _target,
        desc: _desc,
        pic: _pic,
        status: ProgramStatus.REGISTERED,
        allocated: 0
    });

    programs.push(newProgram);
    emit ProgramCreated(newId, _name, _target, _pic);
}
```

Admins can create programs that will be funded using the funds in Danantiri. All programs will be publicly accessible to ensure transparency in fund utilization.

#### 2️⃣ Updating a Funding Program

```solidity
function updateProgram(
    uint256 _programId,
    string calldata _name,
    string calldata _desc,
    address _pic
)
    external
    onlyAdmin
{
    require(programs[_programId].status == ProgramStatus.REGISTERED, "Program is not registered");
    require(bytes(_name).length > 0, "Program name cannot be empty");
    require(bytes(_desc).length > 0, "Description cannot be empty");
    require(_pic != address(0), "PIC address cannot be zero");

    Program storage program = programs[_programId];
    program.name = _name;
    program.desc = _desc;
    program.pic = _pic;

    emit ProgramUpdated(_programId, _name, _desc, _pic);
}
```

If the program's information or financial goal is no longer valid, admins can update the program’s name, description, target amount, and assigned PIC.

#### 3️⃣ Depositing Funds

```solidity
function sendFund(uint256 amount) external {
    require(amount > 0, "Amount must be greater than zero");
    require(idrxToken.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

    totalManagedFund += amount;

    emit FundSent(msg.sender, amount);
}
```

Allows users to **contribute IDRX tokens** to the contract.

#### 4️⃣ Allocating Funds to a Program

```solidity
function allocateFund(uint256 _programId) external onlyAdmin {
    Program storage program = programs[_programId];
    require(program.status == ProgramStatus.REGISTERED, "Program is not registered");

    // Calculate available tokens (contract balance minus tokens already allocated)
    uint256 available = idrxToken.balanceOf(address(this)) - totalAllocated;
    require(available >= program.target, "Allocation must be equal to program target");

    program.allocated += program.target;
    totalAllocated += program.target;
    program.status = ProgramStatus.ALLOCATED;

    emit FundAllocated(_programId, program.target);
}
```

Admin can transfer funds **from contract balance** to a **specific program** which will be funded. If the the program is full funded, then it will change the program status to **ALLOCATED**.

#### 5️⃣ Withdrawing Funds (For PICs)

```solidity
function withdrawFund(uint256 _programId, string calldata _history, uint256 _amount) external onlyPIC(_programId) {
    Program storage program = programs[_programId];
    require(program.status == ProgramStatus.ALLOCATED, "Program is not allocated");
    require(bytes(_history).length > 0, "History cannot be empty");
    require(_amount > 0, "Amount must be greater than zero");
    require(_amount <= program.allocated, "Amount to withdraw exceeds allocated fund");

    // Update allocated amount and total allocated tokens
    program.allocated -= _amount;
    totalAllocated -= _amount;

    // Add history
    programHistories[_programId].push(History({
        timestamp: block.timestamp,
        history: _history,
        amount: _amount
    }));

    require(idrxToken.transfer(msg.sender, _amount), "Token transfer failed");

    emit FundWithdrawn(_programId, msg.sender, _history, _amount);
}
```

Allows **designated PICs** to withdraw **allocated funds**.

#### 6️⃣ Retrieving Program Data

To ensure transparency in fund usage, we will implement functions that allow the external to access and view all registered and allocated programs.


```solidity
function getAllProgram() external view returns (Program[] memory) {
    return programs;
}
```
Returns **all programs**.

```solidity
function getProgramHistory(uint256 _programId) external view returns (History[] memory) {
    return programHistories[_programId];
}
```
Returns **all program's history**.