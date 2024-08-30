// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Voucher is UUPSUpgradeable, Initializable, OwnableUpgradeable {
    using MerkleProof for bytes32[];

    struct Issuance {
        address erc20Address;
        string name;
        bool isReused;
        uint256 totalCodeCount;
        uint256 claimAmountPerCode;
        uint256 claimFrequency;
        uint256 totalIssuedAmount;
        uint256 startTime;
        uint256 endTime;
        bytes32 merkleRoot;
    }

    uint256 public totalIssuanceCount;
    // issuance issuanceIndex => issuance details
    mapping(uint256 issuanceIndex => Issuance issuance) public issuances;
    // issuance issuanceIndex => user => claim count
    mapping(uint256 issuanceIndex => mapping(address user => uint256 claimCount))
        public claimCountPerUser;
    // issuance issuanceIndex => issue code => used or not
    mapping(uint256 issuanceIndex => mapping(string issueCode => bool isUsed))
        public isCodeUsed;
    // issuance issuanceIndex => claimed amount
    mapping(uint256 issuanceIndex => uint256 claimedAmount)
        public claimedAmount;

    event RegisterIssuance(
        uint256 issuanceIndex,
        string name,
        bool isResued,
        uint256 totalCodeCount,
        uint256 claimAmountPerCode,
        uint256 claimFrequency,
        uint256 totalIssuedAmount,
        uint256 startTime,
        uint256 endTime,
        bytes32 merkleRoot
    );

    event Claim(uint256 issuanceIndex, string code);

    function initialize() public initializer {
        __Ownable_init(msg.sender);
    }

    function registerIssuance(
        string memory _name,
        address _erc20Address,
        bool _isReused,
        uint256 _totalCodeCount,
        uint256 _claimAmountPerCode,
        uint256 _claimFrequency,
        uint256 _totalIssuedAmount,
        uint256 _startTime,
        uint256 _endTime,
        bytes32 _merkleRoot
    ) external {
        require(
            (!_isReused &&
                _totalCodeCount * _claimAmountPerCode == _totalIssuedAmount) ||
                (_isReused && _totalCodeCount == 1),
            "Invalid Params!"
        );
        require(_merkleRoot != bytes32(0), "Invalid marketRoot!");
        require(
            _endTime > _startTime,
            "End time should be after than start time!"
        );

        Issuance storage issuance = issuances[totalIssuanceCount];
        totalIssuanceCount++;

        issuance.erc20Address = _erc20Address;
        issuance.name = _name;
        issuance.isReused = _isReused;
        issuance.totalCodeCount = _totalCodeCount;
        issuance.claimAmountPerCode = _claimAmountPerCode;
        issuance.claimFrequency = _claimFrequency;
        issuance.totalIssuedAmount = _totalIssuedAmount;
        issuance.startTime = _startTime;
        issuance.endTime = _endTime;
        issuance.merkleRoot = _merkleRoot;

        IERC20(_erc20Address).transferFrom(
            msg.sender,
            address(this),
            _totalIssuedAmount
        );

        emit RegisterIssuance(
            totalIssuanceCount - 1,
            _name,
            _isReused,
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
        uint256 issuanceIndex,
        string memory code,
        bytes32[] calldata proof
    ) external {
        Issuance memory issuance = issuances[issuanceIndex];

        require(
            issuance.startTime < block.timestamp &&
                block.timestamp < issuance.endTime,
            "Issuance not started or already ended!"
        );
        require(
            claimCountPerUser[issuanceIndex][msg.sender] <
                issuance.claimFrequency,
            "Claim reached limitation!"
        );
        require(
            claimedAmount[issuanceIndex] <= issuance.totalIssuedAmount,
            "No more claimable amount!"
        );

        claimCountPerUser[issuanceIndex][msg.sender]++;
        claimedAmount[issuanceIndex] += issuance.claimAmountPerCode;

        if (!issuance.isReused) {
            require(
                !isCodeUsed[issuanceIndex][code],
                "Claim code already used!"
            );
            isCodeUsed[issuanceIndex][code] = true;
        }
        require(
            proof.verify(
                issuance.merkleRoot,
                keccak256(abi.encodePacked(code))
            ),
            "Invalid claim proof!"
        );

        //transfer(msg.sender, issuance.claimAmountPerCode);

        emit Claim(issuanceIndex, code);
    }

    function _authorizeUpgrade(
        address newImplementation
    ) internal virtual override onlyOwner {}
}
