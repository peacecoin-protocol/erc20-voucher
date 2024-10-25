// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {console} from "forge-std/console.sol";

contract Voucher is UUPSUpgradeable, Initializable, OwnableUpgradeable {
    using MerkleProof for bytes32[];

    struct Issuance {
        string issuanceId;
        address owner;
        address erc20Address;
        string name;
        uint256 totalCodeCount;
        uint256 claimAmountPerCode;
        uint256 claimFrequency;
        uint256 totalIssuedAmount;
        uint256 startTime;
        uint256 endTime;
        bytes32 merkleRoot;
    }

    // issuance issuanceId => issuance details
    mapping(string issuanceId => Issuance issuance) public issuances;
    // issuance issuanceId => user => claim count
    mapping(string issuanceId => mapping(address user => uint256 claimCount))
        public claimCountPerUser;
    // issuance issuanceId => issue code => used or not
    mapping(string issuanceId => mapping(string issueCode => bool isUsed))
        public isCodeUsed;
    // issuance issuanceId => claimed amount
    mapping(string issuanceId => uint256 claimedAmount) public claimedAmount;

    mapping(address erc20Address => string[] issuanceIds)
        public issuanceIdsByErc20Address;

    event RegisterIssuance(
        string issuanceId,
        address owner,
        address erc20Address,
        string name,
        uint256 totalCodeCount,
        uint256 claimAmountPerCode,
        uint256 claimFrequency,
        uint256 totalIssuedAmount,
        uint256 startTime,
        uint256 endTime,
        bytes32 merkleRoot
    );

    event Claim(string issuanceId, string code);

    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }

    function registerIssuance(
        string memory issuanceId,
        string memory _name,
        address _erc20Address,
        uint256 _totalCodeCount,
        uint256 _claimAmountPerCode,
        uint256 _claimFrequency,
        uint256 _totalIssuedAmount,
        uint256 _startTime,
        uint256 _endTime,
        bytes32 _merkleRoot
    ) external {
        require(
            _endTime > _startTime,
            "End time should be after than start time!"
        );
        require(
            bytes(issuances[issuanceId].issuanceId).length == 0,
            "Issuance ID already exists!"
        );

        Issuance storage issuance = issuances[issuanceId];
        issuanceIdsByErc20Address[_erc20Address].push(issuanceId);

        issuance.issuanceId = issuanceId;
        issuance.erc20Address = _erc20Address;
        issuance.name = _name;
        issuance.totalCodeCount = _totalCodeCount;
        issuance.claimAmountPerCode = _claimAmountPerCode;
        issuance.claimFrequency = _claimFrequency;
        issuance.totalIssuedAmount = _totalIssuedAmount;
        issuance.startTime = _startTime;
        issuance.endTime = _endTime;
        issuance.merkleRoot = _merkleRoot;

        require(
            IERC20(_erc20Address).allowance(msg.sender, address(this)) >=
                _totalIssuedAmount,
            "Insufficient allowance"
        );
        IERC20(_erc20Address).transferFrom(
            msg.sender,
            address(this),
            _totalIssuedAmount
        );

        emit RegisterIssuance(
            issuanceId,
            msg.sender,
            _erc20Address,
            _name,
            _totalCodeCount,
            _claimAmountPerCode,
            _claimFrequency,
            _totalIssuedAmount,
            _startTime,
            _endTime,
            _merkleRoot
        );
    }

    function claim(
        string memory issuanceId,
        string memory code,
        bytes32[] calldata proof
    ) external {
        Issuance memory issuance = issuances[issuanceId];
        require(bytes(issuance.issuanceId).length != 0, "Issuance not found!");

        require(
            issuance.startTime < block.timestamp &&
                block.timestamp < issuance.endTime,
            "Issuance not started or already ended!"
        );
        require(
            claimCountPerUser[issuanceId][msg.sender] < issuance.claimFrequency,
            "Claim reached limitation!"
        );
        require(
            claimedAmount[issuanceId] <= issuance.totalIssuedAmount,
            "No more claimable amount!"
        );
        require(
            proof.verify(
                issuance.merkleRoot,
                keccak256(abi.encodePacked(code))
            ),
            "Invalid claim proof!"
        );
        require(!isCodeUsed[issuanceId][code], "Code already used!");
        require(
            IERC20(issuance.erc20Address).balanceOf(address(this)) >=
                issuance.claimAmountPerCode,
            "Insufficient balance"
        );

        claimCountPerUser[issuanceId][msg.sender]++;
        claimedAmount[issuanceId] += issuance.claimAmountPerCode;

        isCodeUsed[issuanceId][code] = true;

        IERC20(issuance.erc20Address).transfer(
            msg.sender,
            issuance.claimAmountPerCode
        );

        emit Claim(issuanceId, code);
    }

    function getIssuanceIdsByErc20Address(
        address _erc20Address
    ) external view returns (string[] memory) {
        return issuanceIdsByErc20Address[_erc20Address];
    }

    function getIssuanceByIssuanceId(
        string memory issuanceId
    ) external view returns (Issuance memory) {
        return issuances[issuanceId];
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}
}
