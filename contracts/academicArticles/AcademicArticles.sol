// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../uds/interfaces/IUDSWrite.sol";
import "../uds/interfaces/IUDSRead.sol";
import "../uds/libs/UDSMessage.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title AcademicArticles
 * @dev A smart contract for publishing academic articles and managing their metadata on the Unified Data Storage (UDS).
 * @author Cleber Lucas
 */
abstract contract AcademicArticles {

    // Structure defining the UDS storage model.
    struct UDSStorageModel {
        bool transferedUDSSignature;    // Flag indicating whether the UDS signature has been transferred.
        bool connectedToUDS;            // Flag indicating whether the contract is connected to UDS.
        IUDSRead read;                  // Interface for reading data from UDS.
        IUDSWrite write;                // Interface for writing data to UDS.
    }

    // Structure defining the model for academic articles published on UDS.
    struct UDSPublicationModel {
        ArticleModel article;   // Details of the academic article.
        address publisher;      // Address of the publisher.
        uint datetime;          // Date and time of publication.
        uint blockNumber;       // Block number of publication.
    }

    // Structure defining the model for an academic article.
    struct ArticleModel {
        string title;               // Title of the article.
        string summary;             // Summary of the article.
        string additionalInfo;      // Additional information about the article.
        string institution;         // Institution associated with the article.
        string course;              // Course associated with the article.
        string articleType;         // Type of the article.
        string academicDegree;      // Academic degree related to the article.
        string documentationCID;    // CID (Content Identifier) of the article documentation.
        string[] authors;           // Authors of the article.
        string[] advisors;          // Advisors of the article.
        string[] examiningBoard;    // Examining board of the article.
        uint16 presentationYear;    // Year of presentation of the article.
    }

    // UDS storage model.
    UDSStorageModel private _UDS;

    // Signature on UDS.
    bytes32 private immutable UDS_SIGNATURE;

     // Owner of the contract.
    address private immutable OWNER;

    // Hash of the secret key.
    bytes32 private immutable SECRET_KEY_HASH;

    // Classification for publications on UDS.                                            
    bytes32 private constant UDS_CLASSIFICATION_PUBLICATION = "Publication";

    /**
     * @dev Constructor function
     * @param secretKeyHash Hash of the secret key.
     * @param UDSSignature UDS signature.
     * @param UDSAccount Address of the UDS account.
     */
    constructor(bytes32 secretKeyHash, bytes32 UDSSignature, address UDSAccount) {
        OWNER = msg.sender;
        SECRET_KEY_HASH = secretKeyHash;
        UDS_SIGNATURE = UDSSignature;

        _UDS.read = IUDSRead(UDSAccount);
        _UDS.write = IUDSWrite(UDSAccount);
    }

    /**
     * @dev Function to sign to UDS.
     */
    function SignToUDS() 
    public {
        require(OWNER == msg.sender, "Owner action");
        require(!_UDS.connectedToUDS, "Already connected to UDS");

        _UDS.write.Sign(UDS_SIGNATURE);
        _UDS.connectedToUDS = true;
    }

    /**
     * @dev Function to transfer UDS signature.
     * @param sender Address of the sender.
     * @param secretKey Secret key for verification.
     * @notice The secret key must be entered only once, as its value will be visible in the transaction
     */
    function TransferUDSSignature(address sender, bytes calldata secretKey) 
    public {
        require(OWNER == msg.sender, "Owner action");
        require(SECRET_KEY_HASH == keccak256(secretKey), "Invalid secretKey");
        require(!_UDS.transferedUDSSignature, "Already transferred UDS signature");

        _UDS.write.TransferSignature(sender);
        _UDS.transferedUDSSignature = true;
    }

    /**
     * @dev Function to publish articles to UDS.
     * @param articles Array of ArticleModel containing details of articles to be published.
     */
    function PublishArticles(ArticleModel[] calldata articles) 
    public {
        bytes32[] memory publicationIds = new bytes32[](articles.length);
        address publisher = msg.sender;

        for (uint i = 0; i < articles.length; i++) {
            bytes32 UDSPublicationId = keccak256(abi.encode(articles[i].summary));

            try _UDS.write.SendMetadata(
                    UDS_CLASSIFICATION_PUBLICATION,
                    UDSPublicationId,
                    abi.encode(
                        UDSPublicationModel(
                            articles[i],
                            publisher,
                            block.timestamp,
                            block.number
                        )
                    )
            ){
                publicationIds[i] = UDSPublicationId;
            } catch Error(string memory errorMessage) {
                if (Strings.equal(errorMessage, UDSMessage.METADATA_ALREADY_SENT)) {
                    revert(string.concat("Article[", Strings.toString(i), "] already published"));
                } else {
                    revert(errorMessage);
                }
            }
        }
    }

    /**
     * @dev Function to unpublish articles from UDS.
     * @param ids Array of publication IDs to be unpublished.
     */
    function UnpublishArticles(bytes32[] calldata ids) 
    public {
        address publisher = msg.sender;

        for (uint i = 0; i < ids.length; i++) {
            bytes32 id = ids[i];
            UDSPublicationModel memory publicationUDS = Publication(id);

            require(publicationUDS.publisher != address(0), string.concat("Article[", Strings.toString(i), "] is not published"));
            require(publicationUDS.publisher == publisher, string.concat("Article[", Strings.toString(i), "] is not published by you"));

            _UDS.write.CleanMetadata(UDS_CLASSIFICATION_PUBLICATION, id);
        }
    }

    /**
     * @dev Function to retrieve publication details by ID.
     * @param id Publication ID.
     * @return publication Publication details.
     */
    function Publication(bytes32 id) 
    public view 
    returns (UDSPublicationModel memory publication) {
        bytes memory UDSPublicationMetadata = _UDS.read.Metadata(UDS_SIGNATURE, UDS_CLASSIFICATION_PUBLICATION, id);

        if (UDSPublicationMetadata.length > 0) {
            publication = abi.decode(UDSPublicationMetadata, (UDSPublicationModel));
        }
    }
}
