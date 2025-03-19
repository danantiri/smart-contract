// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title Danantiri
 * @notice A contract for managing funding programs using IDRX tokens (ERC20).
 */

/**
 * @notice Interface for interacting with an ERC20 token.
 */
interface IERC20 {
    /**
     * @notice Transfers tokens from one address to another.
     * @param sender The address sending the tokens.
     * @param recipient The address receiving the tokens.
     * @param amount The number of tokens to transfer.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    
    /**
     * @notice Transfers tokens to a recipient.
     * @param recipient The address receiving the tokens.
     * @param amount The number of tokens to transfer.
     * @return A boolean value indicating whether the operation succeeded.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);
    
    /**
     * @notice Gets the balance of tokens for an account.
     * @param account The address to query.
     * @return The token balance of the account.
     */
    function balanceOf(address account) external view returns (uint256);
}

contract Danantiri {
    // --------------------------------------------------
    // Enums / Structs
    // --------------------------------------------------
    
    /**
     * @notice Represents the status of a program.
     *         0 -> Inactive, 1 -> Active (partially funded), 2 -> Completed (fully funded)
     */
    enum ProgramStatus { Inactive, Active, Completed }
    
    /**
     * @notice Struct representing a funding program.
     * @dev The `id` is the index in the `programs` array.
     */
    struct Program {
        uint256 id;           ///< Unique identifier
        string name;          ///< Program name
        uint256 target;       ///< Funding target (in tokens)
        string desc;          ///< Program description
        address pic;          ///< Person In Charge (PIC)
        ProgramStatus status; ///< Current funding status
        uint256 allocated;    ///< Tokens allocated to the program
        string[] histories;   ///< History of the program
    }
    
    // --------------------------------------------------
    // State Variables
    // --------------------------------------------------
    
    /// @notice Address of the contract admin.
    address public owner;
    
    /// @notice Array of all programs.
    Program[] public programs;
    
    /// @notice Total tokens allocated across all programs.
    uint256 public totalAllocated;
    
    /// @notice The ERC20 token used for funding (IDRX).
    IERC20 public idrxToken;
    
    // --------------------------------------------------
    // Events
    // --------------------------------------------------
    
    /**
     * @notice Emitted when a new program is created.
     * @param programId The ID of the newly created program.
     * @param name The name of the program.
     * @param target The funding target.
     * @param pic The address designated as PIC.
     */
    event CreatedProgram(uint256 indexed programId, string name, uint256 target, address pic);
    
    /**
     * @notice Emitted when an existing program is updated.
     * @param programId The ID of the updated program.
     * @param name The new name of the program.
     * @param target The new funding target.
     * @param pic The new PIC address.
     */
    event UpdatedProgram(uint256 indexed programId, string name, uint256 target, address pic);
    
    /**
     * @notice Emitted when tokens are sent to the contract as funding.
     * @param sender The address sending the tokens.
     * @param amount The amount of tokens sent.
     */
    event SendFund(address indexed sender, uint256 amount);
    
    /**
     * @notice Emitted when tokens are allocated to a program.
     * @param programId The ID of the program.
     * @param amount The amount of tokens allocated.
     */
    event AllocateFund(uint256 indexed programId, uint256 amount);
    
    /**
     * @notice Emitted when the PIC withdraws allocated tokens.
     * @param programId The ID of the program.
     * @param pic The address of the PIC.
     * @param amount The amount of tokens withdrawn.
     */
    event WithdrawFund(uint256 indexed programId, address indexed pic, uint256 amount);

    /**
     * @notice Emitted when a history is added to a program.
     * @param programId The ID of the program.
     * @param history The history to add.
     */
    event AddHistory(uint256 indexed programId, string history);
    
    // --------------------------------------------------
    // Modifiers
    // --------------------------------------------------
    
    /**
     * @notice Ensures that only the admin can call the function.
     */
    modifier onlyAdmin() {
        require(msg.sender == owner, "Only admin can call this function");
        _;
    }
    
    /**
     * @notice Ensures that the function caller is the PIC of the specified program.
     * @param _programId The program's ID.
     */
    modifier onlyPIC(uint256 _programId) {
        require(msg.sender == programs[_programId].pic, "Not PIC of this program");
        _;
    }
    
    // --------------------------------------------------
    // Constructor
    // --------------------------------------------------
    
    /**
     * @notice Initializes the contract by setting the admin and the IDRX token address.
     * @param _tokenAddress The address of the IDRX ERC20 token.
     */
    constructor(address _tokenAddress) {
        require(_tokenAddress != address(0), "Invalid token address");
        owner = msg.sender;
        idrxToken = IERC20(_tokenAddress);
    }
    
    // --------------------------------------------------
    // Public / External Functions
    // --------------------------------------------------
    
    /**
     * @notice Creates a new funding program.
     * @dev Validates all input parameters.
     * @param _name The name of the program.
     * @param _target The funding target (in tokens).
     * @param _desc The description of the program.
     * @param _pic The PIC's address (must not be the zero address).
     */
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
    
    /**
     * @notice Retrieves all programs that are currently active.
     * @return An array of programs with status Active.
     */
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
    
    /**
     * @notice Retrieves all programs that are completed.
     * @return An array of programs with status Completed.
     */
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
    
    /**
     * @notice Updates an existing program's details.
     * @dev Validates inputs and ensures the program exists.
     * @param _programId The ID of the program to update.
     * @param _name The new name of the program.
     * @param _target The new funding target.
     * @param _desc The new description.
     * @param _pic The new PIC's address.
     */
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
    
    /**
     * @notice Transfers IDRX tokens from the sender to the contract as funding.
     * @dev Requires the sender to have approved this contract to spend tokens on their behalf.
     * @param amount The amount of tokens to send.
     */
    function sendFund(uint256 amount) public {
        require(amount > 0, "Amount must be greater than zero");
        require(idrxToken.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        emit SendFund(msg.sender, amount);
    }
    
    /**
     * @notice Allocates tokens from the contract to a specific program.
     * @dev Checks that allocation does not exceed the program's target or available tokens.
     * @param amount The amount of tokens to allocate.
     * @param _programId The ID of the program.
     */
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
    
    /**
     * @notice Allows the PIC of a program to withdraw the allocated tokens.
     * @dev Withdraws the entire allocated amount and resets it to zero.
     * @param _programId The ID of the program.
     */
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

    /**
     * @notice Adds a history for a program.
     * @param _programId The ID of the program.
     * @param _history The history to add.
     */
    function addHistory(uint256 _programId, string calldata _history) public onlyAdmin {
        programs[_programId].histories.push(_history);

        emit AddHistory(_programId, _history);
    }
}
