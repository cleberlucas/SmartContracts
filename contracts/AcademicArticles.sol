// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

// Import necessary interfaces and libraries
import "./aio/interfaces/IAIOWrite.sol";
import "./aio/interfaces/IAIORead.sol";
import "./aio/interfaces/IAIOSignature.sol";
import "./aio/libs/AIOMessage.sol";
import "./StringUtils.sol";

import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title Academic Articles
 * @notice This is a platform for publishing academic articles
 * @dev Smart contract managing academic articles with integration to the AIO (All in one) platform.
 * @author Cleber Lucas
 */
contract AcademicArticles is IAIOSignature {
    function SIGNATURE() 
    public pure 
    returns (bytes32 signature) {
        signature = "AcademicArticles";
    }

    struct AIO_StorageModel {     
        address account;
        IAIORead read;
        IAIOWrite write;
    }

    struct Publication_AIOModel {
        Article_Model article;
        address publisher;
        uint datetime;
        uint blockNumber;
    }

    struct Publisher_AIOModel {
        bytes32[] ids;
    }

    struct Article_Model {
        string title;
        string summary;
        string additionalInfo;
        string institution;
        string course;
        string articleType;
        string academicDegree;
        string documentationUrl;
        string[] authors;
        string[] advisors;
        string[] examiningBoard;
        uint16 presentationYear;
    }

    struct PublicationPreview_Model {
        string title;
        bytes32 id;
    }

    event ArticlesPublished(bytes32[] indexed ids);

    event ArticlesUnpublished(bytes32[] indexed ids);

    AIO_StorageModel internal _aio;

    bytes32 constant SECRETKEY = 0x07855b46a623a8ecabac76ed697aa4e13631e3b6718c8a0d342860c13c30d2fc;
    bytes32 constant AIO_CLASSIFICATION_PUBLISHER = "Publisher";
    bytes32 constant AIO_CLASSIFICATION_PUBLICATION = "Publication";

    bool connectToAIO;
    bool transferredSignature;

    address immutable OWNER;

    constructor(){
        OWNER = msg.sender;
    }

    function ConnectToAIO(address account) 
    external {
        require (OWNER == msg.sender, "Owner action");
        require (!connectToAIO, "Already connect to AIO");

        IAIOWrite(account).Initialize();
        _aio.read = IAIORead(account);
        _aio.write = IAIOWrite(account);
        _aio.account = account;

        connectToAIO = true;
    }

    function TransferAIOSignature(address newSender, bytes calldata secretKey) 
    external {
        require (OWNER == msg.sender, "Owner action");
        require (SECRETKEY == keccak256(secretKey), "Invalid secretKey");
        require (!transferredSignature, "Already transferred signature");

        transferredSignature = true;

        _aio.write.TransferSignature(newSender);
    }

    function PublishArticles(Article_Model[] calldata articles) 
    external {
        Publisher_AIOModel memory publisherAIO;
        address publisher = msg.sender;
        bytes32 publisherAIOKey = bytes32(abi.encode(publisher));
        bytes32[] memory ids = new bytes32[](articles.length);
        bytes memory publisherAIOEncoded = _aio.read.Metadata(SIGNATURE(), AIO_CLASSIFICATION_PUBLISHER, publisherAIOKey);

        for (uint i = 0; i < articles.length; i++) {
            bytes32 id = keccak256(abi.encode(articles[i]));
            Publication_AIOModel memory publication;

            publication.article = articles[i];
            publication.publisher = publisher;
            publication.datetime = block.timestamp;
            publication.blockNumber = block.number;

            try _aio.write.SendMetadata(AIO_CLASSIFICATION_PUBLICATION, id, abi.encode(publication)) {
            } catch Error(string memory errorMessage) {
                if (keccak256(abi.encodePacked(errorMessage)) == keccak256(abi.encodePacked(AIOMessage.METADATA_ALREADY_SENT))) {
                    revert(string.concat("Article[", Strings.toString(i), "] already published"));          
                } else {
                    revert( errorMessage);
                }
            }
            
            ids[i] = id;
        }

        if (publisherAIOEncoded.length > 0) {
            bytes32[] memory newIds = new bytes32[](publisherAIO.ids.length + ids.length);

            publisherAIO = abi.decode(publisherAIOEncoded, (Publisher_AIOModel));

            for (uint i = 0; i < newIds.length; i++) {
                if (i < publisherAIO.ids.length) {
                    newIds[i] = publisherAIO.ids[i];
                } else {
                    newIds[i] = publisherAIO.ids[i - publisherAIO.ids.length];
                }
            }

            publisherAIO.ids = newIds;
            
            _aio.write.UpdateMetadata(AIO_CLASSIFICATION_PUBLISHER, publisherAIOKey, abi.encode(publisherAIO));
        } else {
            publisherAIO.ids = ids;
            publisherAIOEncoded = abi.encode(publisherAIO);

            _aio.write.SendMetadata(AIO_CLASSIFICATION_PUBLISHER, publisherAIOKey, abi.encode(publisherAIO));
        }

        emit ArticlesPublished(ids);
    }


    function UnpublishArticles(bytes32[] calldata ids) 
    external {
        Publisher_AIOModel memory publisherAIO ;
        bytes32 publisherAIOKey = bytes32(abi.encode(msg.sender));
        bytes memory publisherAIOEncoded = _aio.read.Metadata(SIGNATURE(), AIO_CLASSIFICATION_PUBLISHER, publisherAIOKey);

        if(publisherAIOEncoded.length > 0) {
            publisherAIO = abi.decode(publisherAIOEncoded, (Publisher_AIOModel));
        } else {
            revert ("You have nothing to unpublish");
        }

        for (uint i = 0; i < ids.length; i++) {
            bytes32 id = ids[i]; 
            bytes memory publicationEncode = _aio.read.Metadata(SIGNATURE(), AIO_CLASSIFICATION_PUBLICATION, id);
            Publication_AIOModel memory publicationAIO = abi.decode(publicationEncode, (Publication_AIOModel));

            require (publicationEncode.length > 0, string.concat("Article[", Strings.toString(i), "] is not published"));
            require (publicationAIO.publisher == msg.sender, string.concat("Article[", Strings.toString(i), "] is not published by you"));

            _aio.write.CleanMetadata(AIO_CLASSIFICATION_PUBLICATION, id);     
        }

        if (publisherAIO.ids.length == ids.length) {
            _aio.write.CleanMetadata(AIO_CLASSIFICATION_PUBLISHER, publisherAIOKey);
        } else {  
            bytes32[] memory newIds = new bytes32[](publisherAIO.ids.length - ids.length);
            bool useId;
            uint i_;

            for (uint i = 0; i < publisherAIO.ids.length; i++) {
                useId = true;

                for (uint ii = 0; ii < ids.length; ii++) {
                    if (ids[ii] == publisherAIO.ids[i]) {
                        useId = false;

                        break;
                    }
                }

                if (useId) {
                    newIds[i_] = publisherAIO.ids[i];
                    i_ ++;
                }

                if (i_ == newIds.length) {
                    break;
                }
            }

            publisherAIO.ids = newIds;
            _aio.write.UpdateMetadata(AIO_CLASSIFICATION_PUBLISHER, publisherAIOKey, abi.encode(publisherAIO));
        }

        emit ArticlesUnpublished(ids);
    }

    function PublisherAIO(address publisher) 
    external view 
    returns (Publisher_AIOModel memory publisherAIO) {
        bytes memory publisherAIOEncoded = _aio.read.Metadata(SIGNATURE(), AIO_CLASSIFICATION_PUBLISHER, bytes32(abi.encode(publisher)));

        if(publisherAIOEncoded.length > 0) {
            publisherAIO = abi.decode(publisherAIOEncoded, (Publisher_AIOModel));
        }
    }

    function Publication(bytes32 id) 
    external view 
    returns (Publication_AIOModel memory publication) {
        bytes memory publicationAIOEncoded = _aio.read.Metadata(SIGNATURE(), AIO_CLASSIFICATION_PUBLICATION, id);

        if(publicationAIOEncoded.length > 0) {
            publication = abi.decode(publicationAIOEncoded, (Publication_AIOModel));
        }
    }

    function PreviewPublicationsWithTitle(string memory title, uint limit) 
    external view  
    returns (PublicationPreview_Model[] memory publicationsPreview) {
        bytes32[] memory publicationKeys = _aio.read.Keys(SIGNATURE(), AIO_CLASSIFICATION_PUBLICATION);

        publicationsPreview = new PublicationPreview_Model[](limit);

        uint previewCount;
        for (uint i = 0; i < publicationKeys.length && previewCount < limit; i++) {
            bytes32 id = publicationKeys[i];
            Publication_AIOModel memory publication = abi.decode(_aio.read.Metadata(SIGNATURE(), AIO_CLASSIFICATION_PUBLICATION, id), (Publication_AIOModel));
            string memory articleTitle = StringUtils.ToLower(publication.article.title);

            if (StringUtils.ContainWord(articleTitle, StringUtils.ToLower(title))) {
                publicationsPreview[previewCount] = PublicationPreview_Model(articleTitle, id);
                previewCount++;
            }
        }

        if (previewCount < limit) {
            PublicationPreview_Model[] memory publicationsPreviewCopy = publicationsPreview;

            publicationsPreview = new PublicationPreview_Model[](previewCount);
            
            for (uint i = 0; i < previewCount; i++) {
                if (publicationsPreviewCopy[i].id != bytes32(0)) {
                    publicationsPreview[i] = publicationsPreviewCopy[i];
                } else {
                    break;
                }
            }
        }
    }

    function PreviewPublications(uint startIndex, uint endIndex) 
    external view 
    returns (PublicationPreview_Model[] memory publicationsPreview, uint currentSize) {     
        currentSize = _aio.read.Keys(SIGNATURE(), AIO_CLASSIFICATION_PUBLICATION).length;

        if (startIndex >= currentSize || startIndex > endIndex) {
            publicationsPreview = new PublicationPreview_Model[](0);
        } else {
            uint size = endIndex - startIndex + 1;
            
            size = (size <= currentSize - startIndex) ? size : currentSize - startIndex;
            publicationsPreview = new PublicationPreview_Model[](size); 
            
            for (uint i = 0; i < size; i++) {
                publicationsPreview[i] = PublicationPreview_Model(
                    abi.decode(_aio.read.Metadata(SIGNATURE(), AIO_CLASSIFICATION_PUBLICATION, _aio.read.Keys(SIGNATURE(), AIO_CLASSIFICATION_PUBLICATION)[startIndex + i]), (Publication_AIOModel)).article.title,
                    _aio.read.Keys(SIGNATURE(), AIO_CLASSIFICATION_PUBLICATION)[startIndex + i]
                );
            }
        }
    }

    function PreviewPublicationsOfPublisher(address publisher, uint startIndex, uint endIndex) 
    external view 
    returns (PublicationPreview_Model[] memory previewPublicationsOfPublisher, uint currentSize) {
        bytes memory publisherAIOEncoded = _aio.read.Metadata(SIGNATURE(), AIO_CLASSIFICATION_PUBLISHER, bytes32(abi.encode(publisher)));

        if(publisherAIOEncoded.length > 0) {
            Publisher_AIOModel memory publisherAIO = abi.decode(publisherAIOEncoded, (Publisher_AIOModel));
            
            currentSize = publisherAIO.ids.length;

            if (startIndex >= currentSize || startIndex > endIndex) {
                previewPublicationsOfPublisher = new PublicationPreview_Model[](0);
            } else {
                uint size = endIndex - startIndex + 1;
                
                size = (size <= currentSize - startIndex) ? size : currentSize - startIndex;
                previewPublicationsOfPublisher = new PublicationPreview_Model[](size); 
                
                for (uint i = 0; i < size; i++) {
                    previewPublicationsOfPublisher[i] = PublicationPreview_Model(
                        abi.decode(_aio.read.Metadata(SIGNATURE(), AIO_CLASSIFICATION_PUBLICATION, publisherAIO.ids[startIndex + i]), (Publication_AIOModel)).article.title,
                        publisherAIO.ids[startIndex + i]
                    );
                }
            }
        } 
    }
}