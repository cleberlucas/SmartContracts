// SPDX-License-Identifier: AFL-3.0
import "./DelimitationLibrary.sol";

pragma solidity >=0.8.22;

library RepositoryLibrary {  
    struct Article {
        bytes32[] hashIdentifiers;
        mapping(bytes32 hashIdentifier => address) poster;
        mapping(bytes32 hashIdentifier => address) institution;
        mapping(bytes32 hashIdentifier => DelimitationLibrary.Article) content; 
    }

    struct Institution {
        address[] accounts;
        mapping(address account => DelimitationLibrary.Institution) content;
        mapping(address account => address[]) authenticators;
    }
}