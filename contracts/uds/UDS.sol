// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// Import external contract interfaces
import "./UDSWrite.sol";
import "./UDSRead.sol";

/**
 * @title Unified data storage (UDS)
 * @dev This is a platform for storing contract data
 * @notice Unified storage platform where data is managed and classified by contracts utilizing this medium through their unique signatures.
 *      Storing data outside the contract enhances modularity and extensibility, as the data isn't stored directly within it.
 * @author Cleber Lucas
 */
contract UDS is UDSWrite, UDSRead {}