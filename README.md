# Danantiri - Blockchain-Based Government Fund Tracking

## Overview

Danantiri is a **blockchain-based** smart contract system designed to **track and manage government funds** with full **transparency and accountability**. Built using **Solidity**, Danantiri utilizes IDRX tokens as the primary payment method.

Danantiri ensures that **all fund transactions are recorded on-chain**, making the system **immutable and verifiable**. Every allocation and withdrawal is **publicly auditable**, preventing misuse and fraud.

## Features

- 📌 **`Create & manage funding programs`** with specific goals and descriptions.  
- ✏️ **`Update program details`** including name, target amount, description, and PIC.  
- 💰 **`Fund allocation`** for active programs.  
- 💸 **`Send funds`** with IDRX tokens.  
- 🔄 **`Withdraw funds`** securely by designated PIC.  
- 📜 **`Retrieve program status`** (Active, Completed, or Inactive).  
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
    enum ProgramStatus { Inactive, Active, Completed }

    struct Program {
        uint256 id;
        string name;
        uint256 target;
        string desc;
        address pic;
        ProgramStatus status;
        uint256 allocated;
    }
}
```

Programs are structured to ensure clear tracking with:

- **`Name & Description`** 🏷️ – Provides transparency on program objectives.
- **`Target Funding Amount`** 💲 – Defines the financial goal of the program.
- **`Assigned PIC`** 👤 – Assign responsible individual for the program.
- **`Status (Inactive, Active, Completed)`** 📡 – Tracks progress and ensures visibility.
- **`Allocated Funds`** 💰 – Displays the amount of funds committed to the program.

### 📜 Danantiri Contract State Variables

Let's define all the necessary variables required for the Danantiri smart contract.

```solidity
address public owner;
Program[] public programs;
uint256 public totalAllocated;
IERC20 public idrxToken;
```
- **`owner`** 🏛️ – The administrator who has the authority to create and manage programs.
- **`programs`** 📋 – A list of all registered funding programs stored on-chain.
- **`totalAllocated`** 💰 – Tracks the total amount of IDRX tokens that have been distributed to programs.
- **`idrxToken`** 🔗 – The ERC20 token contract used for all transactions within Danantiri.

### 📜 Events

```solidity
event CreatedProgram(uint256 indexed programId, string name, uint256 target, address pic);
event UpdatedProgram(uint256 indexed programId, string name, uint256 target, address pic);
event SendFund(address indexed sender, uint256 amount);
event AllocateFund(uint256 indexed programId, uint256 amount);
event WithdrawFund(uint256 indexed programId, address indexed pic, uint256 amount);
```
Events will be used to communicate with external application

### 🔐 Access Control

**Admin-Only Functions**

```solidity
modifier onlyAdmin() {
    require(isAdmin(msg.sender), "Only admin can call this function");
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
        public
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
            status: ProgramStatus.Active,
            allocated: 0
        });

        programs.push(newProgram);
        emit CreatedProgram(newId, _name, _target, _pic);
    }
```

Admins can create programs that will be funded using the funds in Danantiri. All programs will be publicly accessible to ensure transparency in fund utilization.

#### 2️⃣ Updating a Funding Program

```solidity
function updateProgram(
        uint256 _programId,
        string calldata _name,
        uint256 _target,
        string calldata _desc,
        address _pic
    )
        public
        onlyAdmin
    {
        require(programs[_programId].status == ProgramStatus.Active, "Program is not active");
        require(bytes(_name).length > 0, "Program name cannot be empty");
        require(_target > 0, "Target must be greater than zero");
        require(bytes(_desc).length > 0, "Description cannot be empty");
        require(_pic != address(0), "PIC address cannot be zero");

        Program storage program = programs[_programId];
        program.name = _name;
        program.target = _target;
        program.desc = _desc;
        program.pic = _pic;

        emit UpdatedProgram(_programId, _name, _target, _pic);
    }
```

If the program's information or financial goal is no longer valid, admins can update the program’s name, description, target amount, and assigned PIC.

#### 3️⃣ Depositing Funds

```solidity
function sendFund(uint256 amount) public {
    require(amount > 0, "Amount must be greater than zero");
    require(idrxToken.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

    emit SendFund(msg.sender, amount);
}
```

Allows users to **contribute IDRX tokens** to the contract.

#### 4️⃣ Allocating Funds to a Program

```solidity
function allocateFund(uint256 amount, uint256 _programId) public onlyAdmin {
    require(programs[_programId].status == ProgramStatus.Active, "Program is not active");
    require(amount > 0, "Allocation amount must be greater than 0");

    // Calculate available tokens (contract balance minus tokens already allocated)
    uint256 available = idrxToken.balanceOf(address(this)) - totalAllocated;
    require(available >= amount, "Not enough available tokens in contract");

    Program storage program = programs[_programId];
    require(program.allocated + amount > program.target, "Allocation exceeds program target");

    program.allocated += amount;
    totalAllocated += amount;

    // Update program status based on the new allocation
    if (program.allocated == program.target) {
        program.status = ProgramStatus.Completed;
    }

    emit AllocateFund(_programId, amount);
}
```

Admin can transfer funds **from contract balance** to a **specific program** which will be funded. If the the program is full funded, then it will change the program status to **Completed**.

#### 5️⃣ Withdrawing Funds (For PICs)

```solidity
function withdrawFund(uint256 _programId) public onlyPIC(_programId) {
    Program storage program = programs[_programId];
    uint256 amount = program.allocated;
    require(amount > 0, "No allocated fund to withdraw");

    // Reset allocated amount and update the total allocated tokens
    program.allocated = 0;
    totalAllocated -= amount;

    require(idrxToken.transfer(msg.sender, amount), "Token transfer failed");

    emit WithdrawFund(_programId, msg.sender, amount);
}
```

Allows **designated PICs** to withdraw **allocated funds**.

#### 6️⃣ Retrieving Program Data

To ensure transparency in fund usage, we will implement functions that allow the public to access and view all active and completed programs.

```solidity
function getActiveProgram() public view returns (Program[] memory) {
    uint256 count;
    for (uint256 i = 0; i < programs.length; i++) {
        if (programs[i].status == ProgramStatus.Active) {
            count++;
        }
    }
    Program[] memory activePrograms = new Program[](count);
    uint256 index;
    for (uint256 i = 0; i < programs.length; i++) {
        if (programs[i].status == ProgramStatus.Active) {
            activePrograms[index] = programs[i];
            index++;
        }
    }
    return activePrograms;
}
```
Returns **all active funding programs**.

```solidity
function getCompletedProgram() public view returns (Program[] memory) {
    uint256 count;
    for (uint256 i = 0; i < programs.length; i++) {
        if (programs[i].status == ProgramStatus.Completed) {
            count++;
        }
    }
    Program[] memory completedPrograms = new Program[](count);
    uint256 index;
    for (uint256 i = 0; i < programs.length; i++) {
        if (programs[i].status == ProgramStatus.Completed) {
            completedPrograms[index] = programs[i];
            index++;
        }
    }
    return completedPrograms;
}
```
Returns **all fully funded programs**.

### 📜 Final Version of The Smart Contract

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IERC20 {
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
}

contract Danantiri {
    enum ProgramStatus { Inactive, Active, Completed }
    
    struct Program {
        uint256 id; 
        string name;
        uint256 target;
        string desc;
        address pic;
        ProgramStatus status;
        uint256 allocated;
    }
    address public owner;
    Program[] public programs;
    uint256 public totalAllocated;
    IERC20 public idrxToken;

    event CreatedProgram(uint256 indexed programId, string name, uint256 target, address pic);
    event UpdatedProgram(uint256 indexed programId, string name, uint256 target, address pic);
    event SendFund(address indexed sender, uint256 amount);
    event AllocateFund(uint256 indexed programId, uint256 amount);
    event WithdrawFund(uint256 indexed programId, address indexed pic, uint256 amount);
    
    modifier onlyAdmin() {
        require(msg.sender == owner, "Only admin can call this function");
        _;
    }

    modifier onlyPIC(uint256 _programId) {
        require(msg.sender == programs[_programId].pic, "Not PIC of this program");
        _;
    }

    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Invalid token address");
        owner = msg.sender;
        idrxToken = IERC20(_tokenAddress);
    }
    
    function createProgram(
        string calldata _name,
        uint256 _target,
        string calldata _desc,
        address _pic
    )
        public
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
            status: ProgramStatus.Active,
            allocated: 0
        });

        programs.push(newProgram);
        emit CreatedProgram(newId, _name, _target, _pic);
    }
    
    function getActiveProgram() public view returns (Program[] memory) {
        uint256 count;
        for (uint256 i = 0; i < programs.length; i++) {
            if (programs[i].status == ProgramStatus.Active) {
                count++;
            }
        }
        Program[] memory activePrograms = new Program[](count);
        uint256 index;
        for (uint256 i = 0; i < programs.length; i++) {
            if (programs[i].status == ProgramStatus.Active) {
                activePrograms[index] = programs[i];
                index++;
            }
        }
        return activePrograms;
    }

    function getCompletedProgram() public view returns (Program[] memory) {
        uint256 count;
        for (uint256 i = 0; i < programs.length; i++) {
            if (programs[i].status == ProgramStatus.Completed) {
                count++;
            }
        }
        Program[] memory completedPrograms = new Program[](count);
        uint256 index;
        for (uint256 i = 0; i < programs.length; i++) {
            if (programs[i].status == ProgramStatus.Completed) {
                completedPrograms[index] = programs[i];
                index++;
            }
        }
        return completedPrograms;
    }
    
    function updateProgram(
        uint256 _programId,
        string calldata _name,
        uint256 _target,
        string calldata _desc,
        address _pic
    )
        public
        onlyAdmin
    {
        require(programs[_programId].status == ProgramStatus.Active, "Program is not active");
        require(bytes(_name).length > 0, "Program name cannot be empty");
        require(_target > 0, "Target must be greater than zero");
        require(bytes(_desc).length > 0, "Description cannot be empty");
        require(_pic != address(0), "PIC address cannot be zero");

        Program storage program = programs[_programId];
        program.name = _name;
        program.target = _target;
        program.desc = _desc;
        program.pic = _pic;

        emit UpdatedProgram(_programId, _name, _target, _pic);
    }

    function sendFund(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        require(idrxToken.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        emit SendFund(msg.sender, amount);
    }
    
    function allocateFund(uint256 amount, uint256 _programId) public onlyAdmin {
        require(programs[_programId].status == ProgramStatus.Active, "Program is not active");
        require(amount > 0, "Allocation amount must be greater than 0");

        // Calculate available tokens (contract balance minus tokens already allocated)
        uint256 available = idrxToken.balanceOf(address(this)) - totalAllocated;
        require(available >= amount, "Not enough available tokens in contract");

        Program storage program = programs[_programId];
        require(program.allocated + amount > program.target, "Allocation exceeds program target");

        program.allocated += amount;
        totalAllocated += amount;

        // Update program status based on the new allocation
        if (program.allocated == program.target) {
            program.status = ProgramStatus.Completed;
        }

        emit AllocateFund(_programId, amount);
    }
    
    function withdrawFund(uint256 _programId) public onlyPIC(_programId) {
        Program storage program = programs[_programId];
        uint256 amount = program.allocated;
        require(amount > 0, "No allocated fund to withdraw");

        // Reset allocated amount and update the total allocated tokens
        program.allocated = 0;
        totalAllocated -= amount;

        require(idrxToken.transfer(msg.sender, amount), "Token transfer failed");

        emit WithdrawFund(_programId, msg.sender, amount);
    }
}
```