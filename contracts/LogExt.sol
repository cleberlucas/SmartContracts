// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

abstract contract LogExt {
    event InstitutionRegistered(address indexed institutionAccount);

    event InstitutionUnregistered(address indexed institutionAccount);

    event AffiliationLinked(address indexed affiliationAccount);

    event AffiliationUnlinked(address indexed affiliationAccount);

    event ArticleValidated(bytes32 indexed articleId);

    event ArticleInvalidated(bytes32 indexed articleId);

    event ArticlePublished(bytes32 indexed articleId);

    event ArticleUnpublished(bytes32 indexed articleId);
}