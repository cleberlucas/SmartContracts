// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "./AcademicArticlesModelLib.sol";

interface IAcademicArticlesRead {
    function SearchArticlesId(uint256 startIndex, uint256 endIndex) external view returns (bytes32[] memory result, uint256 currentSize);
    function SearchArticlesPoster(bytes32[] memory articlesId) external view returns (address[] memory result);
    function SearchArticlesInstitutionStamp(bytes32[] memory articlesId) external view returns (address[] memory result);
    function SearchArticlesContent(bytes32[] memory articlesId) external view returns (AcademicArticlesModelLib.Article[] memory result);
    function SearchInstitutionsAccount(uint256 startIndex, uint256 endIndex) external view returns (address[] memory result, uint256 currentSize);
    function SearchInstitutionsAffiliates(address[] memory institutionsAccount, uint256 startIndex, uint256 endIndex) external view returns (address[][] memory result, uint256[] memory currentSize);
}