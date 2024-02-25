// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./libs/UDSStorageModel.sol";

/**
 * @title UDSStorage
 * @dev Abstract contract implementing the storage components for Unified Data Storage (UDS).
 */
abstract contract UDSStorage {
    /// @dev Internal instance of UDSStorageModel.Data for managing data.
    UDSStorageModel.Data internal _data;
    
    /// @dev Internal instance of UDSStorageModel.Interconnection for managing sender interconnection.
    UDSStorageModel.Interconnection internal _interconnection;
}
