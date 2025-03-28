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
     *         0 -> INACTIVE, 1 -> REGISTERED (partially funded), 2 -> ALLOCATED (fully funded)
     */
    enum ProgramStatus { INACTIVE, REGISTERED, ALLOCATED }
    
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
    }

    /**
     * @notice Represents a history entry for a program.
     * @param timestamp The timestamp of the history entry.
     * @param history The history message.
     * @param amount The amount of tokens involved in the history entry.
     */
    struct History {
        uint256 timestamp;
        string history;
        uint256 amount;
    }
    
    // --------------------------------------------------
    // State Variables
    // --------------------------------------------------
    
    /// @notice Address of the contract admin.
    address public owner;
    
    /// @notice Array of all programs.
    Program[] public programs;

    /// @notice Total tokens managed by the contract.
    uint256 public totalManagedFund;
    
    /// @notice Total tokens allocated across all programs.
    uint256 public totalAllocated;
    
    /// @notice The ERC20 token used for funding (IDRX).
    IERC20 public idrxToken;

    /// @notice Mapping of program IDs to their history.
    mapping(uint256 => History[]) public programHistories;
    
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
    event ProgramCreated(uint256 indexed programId, string name, uint256 target, address pic);
    
    /**
     * @notice Emitted when an existing program is updated.
     * @param programId The ID of the updated program.
     * @param name The new name of the program.
     * @param desc The new description of the program.
     * @param pic The new PIC address.
     */
    event ProgramUpdated(uint256 indexed programId, string name, string desc, address pic);
    
    /**
     * @notice Emitted when tokens are sent to the contract as funding.
     * @param sender The address sending the tokens.
     * @param amount The amount of tokens sent.
     */
    event FundSent(address indexed sender, uint256 amount);
    
    /**
     * @notice Emitted when tokens are allocated to a program.
     * @param programId The ID of the program.
     * @param amount The amount of tokens allocated.
     */
    event FundAllocated(uint256 indexed programId, uint256 amount);
    
    /**
     * @notice Emitted when the PIC withdraws allocated tokens.
     * @param programId The ID of the program.
     * @param pic The address of the PIC.
     * @param history The history of the withdrawal.
     * @param amount The amount of tokens withdrawn.
     */
    event FundWithdrawn(uint256 indexed programId, address indexed pic, string history, uint256 amount);
    
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
    // External Functions
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
    
    /**
     * @notice Updates an existing program's details.
     * @dev Validates inputs and ensures the program exists.
     * @param _programId The ID of the program to update.
     * @param _name The new name of the program.
     * @param _desc The new description.
     * @param _pic The new PIC's address.
     */
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
    
    /**
     * @notice Transfers IDRX tokens from the sender to the contract as funding.
     * @dev Requires the sender to have approved this contract to spend tokens on their behalf.
     * @param amount The amount of tokens to send.
     */
    function sendFund(uint256 amount) external {
        require(amount > 0, "Amount must be greater than zero");
        require(idrxToken.transferFrom(msg.sender, address(this), amount), "Token transfer failed");

        totalManagedFund += amount;

        emit FundSent(msg.sender, amount);
    }
    
    /**
     * @notice Allocates tokens from the contract to a specific program.
     * @dev Checks that allocation does not exceed the program's target or available tokens. (allocation = target)
     * @param _programId The ID of the program.
     */
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
    
    /**
     * @notice Allows the PIC of a program to withdraw the allocated tokens.
     * @dev Withdraws the entire allocated amount and resets it to zero.
     * @param _programId The ID of the program.
     * @param _history The history of the withdrawal.
     * @param _amount The amount of tokens to withdraw.
     */
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
    
    /**
     * @notice Retrieves all programs.
     * @return An array of programs.
     */
    function getAllProgram() external view returns (Program[] memory) {
        return programs;
    }

    /**
     * @notice Retrieves the history of a specific program.
     * @param _programId The ID of the program.
     * @return An array of history entries.
     */
    function getProgramHistory(uint256 _programId) external view returns (History[] memory) {
        return programHistories[_programId];
    }
}
