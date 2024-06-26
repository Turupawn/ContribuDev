// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import { IEAS, AttestationRequest, AttestationRequestData, RevocationRequest, RevocationRequestData } from "@ethereum-attestation-service/eas-contracts/contracts/IEAS.sol";
import { ISchemaRegistry, SchemaRecord, ISchemaResolver } from "@ethereum-attestation-service/eas-contracts/contracts/ISchemaRegistry.sol";
import { NO_EXPIRATION_TIME, EMPTY_UID } from "@ethereum-attestation-service/eas-contracts/contracts/Common.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ContribuData is Ownable {
    mapping(uint nftId => mapping(uint8 contributionType => uint timestamp)) public contributionTimestamps;
    mapping(uint nftId => mapping(uint8 contributionType => uint amount)) public contributionAmounts;
    mapping(uint id => string name) contributionTypes;

    address public contribuAddress;
    
    // Getters
    function getContributionTimestamps(uint nftId, uint8 contributionType) public view returns(uint timestamp) {
        return contributionTimestamps[nftId][contributionType];
    }
    function getContributionAmounts(uint nftId, uint8 contributionType) public view returns(uint amount) {
        return contributionAmounts[nftId][contributionType];
    }
    function getContributionTypes(uint id) public view returns(string memory name) {
        return contributionTypes[id];
    }

    // Setters
    function setContributionTimestamps(uint nftId, uint8 contributionType, uint timestamp) public onlyContribu {
        contributionTimestamps[nftId][contributionType] = timestamp;
    }
    function setContributionAmounts(uint nftId, uint8 contributionType, uint amount) public onlyContribu {
        contributionAmounts[nftId][contributionType] = amount;
    }
    function setContributionTypes(uint id, string memory name) public onlyContribu {
        contributionTypes[id] = name;
    }

    // Owner
    function setContribuAddress(address contribuAddress_) public {
        contribuAddress = contribuAddress_;
    }

    // Modifiers
    modifier onlyContribu() {
        require(msg.sender == contribuAddress, "Caller is not Contribu");
        _;
    }
}

contract ContributionsNFT is ERC721 {
    // Scroll
    //address public eas = 0x310359aBD92081b2a9F3ef347858708089B633d5;
    //address public schemaRegistry = 0xf3f4BDc8C7498208256a47bb1C5fB308CDe67c3E;
    // OP
    address public eas = 0x4200000000000000000000000000000000000021;
    address public schemaRegistry = 0x4200000000000000000000000000000000000020;
    bytes32 public schemaID;
    uint public contributionDecayTime = 1 minutes;
    uint8 public maxContributionAmount = 5;
    uint public tokenCount;
    mapping(address => bool) public operators;

    string public baseTokenURI;

    ContribuData contribuData;

    // Contructor
    constructor(address _eas,
            address _schemaRegistry,
            address contribuDataAddress,
            string memory _NFTName,
            string memory _NFTSymbol) ERC721(_NFTName, _NFTSymbol) {
        eas = _eas;
        schemaRegistry = _schemaRegistry;
        contribuData = ContribuData(contribuDataAddress);
        operators[msg.sender] = true;      
    }

    // Modifiers
    modifier onlyOperator() {
        require(operators[msg.sender], "Caller is not operator");
        _;
    }

    // onlyOperator functions
    function setOperator(address operator, bool value) public onlyOperator {
        operators[operator] = value;
    }

    function setBaseURI(string memory baseURI) public onlyOperator {
        baseTokenURI = baseURI;
    }

    function setContribuData(address contribuDataAddress) public onlyOperator {
        contribuData = ContribuData(contribuDataAddress);
    }

    function mint(address to) public onlyOperator
    {
        tokenCount  += 1;
        _mint(to, tokenCount);
    }

    function burn(uint nftId) public onlyOperator
    {
        _burn(nftId);
    }

    function setContribution(
        uint nftId,
        uint8 contributionTypeId,
        uint8 contributionAmount,
        string memory description
        ) public onlyOperator returns(bytes32)
    {
        require(contributionAmount <= maxContributionAmount, "Invalid contribution amount");
        contribuData.setContributionAmounts(nftId, contributionTypeId,
            getContribution(nftId, contributionTypeId) + contributionAmount);
        contribuData.setContributionTimestamps(nftId, contributionTypeId,
            block.timestamp);

        uint64 expirationTime = uint64(block.timestamp + contributionDecayTime*contributionAmount);

        bytes memory encodedData = abi.encode(msg.sender, nftId, contribuData.getContributionTypes(contributionTypeId), contributionAmount, description);
        return
            IEAS(eas).attest(
                AttestationRequest({
                    schema: schemaID,
                    data: AttestationRequestData({
                        recipient: ownerOf(nftId),
                        expirationTime: expirationTime,
                        revocable: true,
                        refUID: EMPTY_UID,
                        data: encodedData,
                        value: 0
                    })
                })
            );
    }

    function setContributionLean(
        uint nftId,
        uint8 contributionTypeId,
        uint8 contributionAmount
        ) public onlyOperator returns(bytes32)
    {
        require(contributionAmount <= maxContributionAmount, "Invalid contribution amount");
        contribuData.setContributionAmounts(nftId, contributionTypeId,
            getContribution(nftId, contributionTypeId) + contributionAmount);
        contribuData.setContributionTimestamps(nftId, contributionTypeId,
            block.timestamp);

        uint64 expirationTime = uint64(block.timestamp + contributionDecayTime*contributionAmount);

        bytes memory encodedData = abi.encode(msg.sender, nftId, contribuData.getContributionTypes(contributionTypeId), contributionAmount, "");
        return
            IEAS(eas).attest(
                AttestationRequest({
                    schema: schemaID,
                    data: AttestationRequestData({
                        recipient: ownerOf(nftId),
                        expirationTime: expirationTime,
                        revocable: true,
                        refUID: EMPTY_UID,
                        data: encodedData,
                        value: 0
                    })
                })
            );
    }

    function multiSetContribution(
        uint[] memory _nftIds,
        uint8[] memory _contributionTypeIds,
        uint8[] memory _contributionAmounts,
        string[] memory _descriptions
        ) public onlyOperator
    {
        for(uint i=0; i<_nftIds.length; i++)
        {
            setContribution(_nftIds[i],
                _contributionTypeIds[i],
                _contributionAmounts[i],
                _descriptions[i]
                );
        }
    }

    function multiSetContributionLean(
        uint[] memory _nftIds,
        uint8[] memory _contributionTypeIds,
        uint8[] memory _contributionAmounts
        ) public onlyOperator
    {
        for(uint i=0; i<_nftIds.length; i++)
        {
            setContributionLean(_nftIds[i],
                _contributionTypeIds[i],
                _contributionAmounts[i]
                );
        }
    }

    function revokeAttestation(bytes32 attestationID) onlyOperator external {
        IEAS(eas).revoke(RevocationRequest({ schema: schemaID, data: RevocationRequestData({ uid: attestationID, value: 0 }) }));
    }

    function setEAS(address _eas) onlyOperator public {
        eas = _eas;
    }

    function setSchemaRegistry(address _schemaRegistry) onlyOperator public {
        schemaRegistry = _schemaRegistry;
    }

    function setSchemaID(bytes32 _schemaID) onlyOperator public {
        schemaID = _schemaID;
    }

    function setContributionDecayTime(uint _contributionDecayTime) onlyOperator public {
        contributionDecayTime = _contributionDecayTime;
    }

    function setMaxContributionAmount(uint8 _maxContributionAmount) onlyOperator public {
        maxContributionAmount = _maxContributionAmount;
    }

    function setContributionType(uint id, string memory name) onlyOperator public {
        contribuData.setContributionTypes(id,
            name);
    }

    // View functions

    function getContribution(uint nftId, uint8 contributionTypeId) public view returns(uint)
    {
        uint lastContributionTimestamp = contribuData.getContributionTimestamps(nftId, contributionTypeId);
        uint lastContributionAmount = contribuData.getContributionAmounts(nftId, contributionTypeId);
        uint elapsedTimeSinceLastContribution = block.timestamp - lastContributionTimestamp;
        uint contributionDecay = elapsedTimeSinceLastContribution / contributionDecayTime;
        if(lastContributionAmount < contributionDecay)
        {
            return 0;
        }
        uint currentContribution = lastContributionAmount - contributionDecay;
        return currentContribution;
    }

    function getContributions(uint nftId, uint8[] memory contributionTypeIds) public view returns(uint[] memory)
    {
        uint[] memory resultArray = new uint[](contributionTypeIds.length);
        for(uint i=0; i<contributionTypeIds.length; i++)
        {
            resultArray[i] = getContribution(nftId, contributionTypeIds[i]);
        }
        return resultArray;
    }

    // Internal functions

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }
}