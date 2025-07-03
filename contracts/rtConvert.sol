// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./utils/SafeMath.sol";
import "./utils/TransferHelper.sol";
import "./utils/Ownable.sol";
import "./utils/ReentrancyGuard.sol";
import "./interface/IrtERC20.sol";

interface IltERC20Price is IERC20 {
    function getPrice() external returns (uint256);
}

contract rtConvert is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    address public immutable ltToken;
    address public immutable rtToken;
    address public ltPrice;
    address public feeReceive = 0x2cb60503C20027EE80502Dc291d09F36DfED026E;
    bool public enabledConvertIn = true;
    bool public enabledConvertOut = true;
    uint256 public rate = 10000;
    uint256 public inFee = 0;
    uint256 public outFee = 0;

    uint256 public wethInFee = 0;
    uint256 public wethOutFee = 30;

    address assetManager;
    address admin;

    modifier onlyAssetManager() {
        require(msg.sender == assetManager, "permissions error");
        _;
    }

    modifier onlyAdmin() {
        require(msg.sender == admin, "permissions error");
        _;
    }

    event Swap(address indexed user, address tokenA, address tokenB, uint256 inAmount, uint256 outAmount);

    constructor(
        address _ltToken,
        address _rtToken,
        address _price,
        address _admin,
        address _assetManger
    ) Ownable(msg.sender) {
        require(_price != address(0), "Cannot be zero address");
        require(_assetManger != address(0), "Cannot be zero address");
        require(_admin != address(0), "Cannot be zero address");
        require(_ltToken != address(0), "Cannot be zero address");
        require(_rtToken != address(0), "Cannot be zero address");
        ltToken = _ltToken;
        rtToken = _rtToken;
        ltPrice = _price;
        admin = _admin;
        assetManager = _assetManger;
    }

    function convert(address tokenA, uint256 _amount) public payable nonReentrant {
        require(tokenA == ltToken || tokenA == rtToken, "Unsupported tokens");

        if (tokenA == ltToken) {
            _convertIn(_amount);
        } else {
            _convertOut(_amount);
        }
    }
    function _convertIn(uint256 _amount) internal {
        require(enabledConvertIn == true, "Convert not enabled");

        uint256 _ltFee = (_amount * inFee) / 10000;
        uint256 _outAmount = ((_amount - _ltFee) * rate) / 10000;

        IERC20(ltToken).safeTransferFrom(msg.sender, address(this), _amount);
        if (_ltFee > 0) {
            IERC20(ltToken).safeTransfer(feeReceive, _ltFee);
        }
        _takeWethFee(_amount, wethInFee);

        IrtERC20(rtToken).mintTo(msg.sender, _outAmount);

        emit Swap(msg.sender, ltToken, rtToken, _amount, _outAmount);
    }

    function _convertOut(uint256 _amount) internal {
        require(enabledConvertOut == true, "Convert not opened");
        uint256 _outAmount = (_amount * 10000) / rate;
        uint256 _feeAmount = (_outAmount * outFee) / 10000;

        _takeWethFee(_outAmount, wethOutFee);

        TransferHelper.safeTransferFrom(rtToken, msg.sender, address(this), _amount);
        IrtERC20(rtToken).burn(IrtERC20(rtToken).balanceOf(address(this)));

        if (_feeAmount > 0) {
            IERC20(ltToken).safeTransfer(feeReceive, _feeAmount);
        }
        IERC20(ltToken).safeTransfer(msg.sender, _outAmount - _feeAmount);

        emit Swap(msg.sender, rtToken, ltToken, _amount, _outAmount);
    }

    function _takeWethFee(uint256 _amount, uint256 _feeRate) internal {
        if (_feeRate > 0) {
            uint256 _feeAmount = _amount.mul(_feeRate).div(10000);
            uint256 _btcFee = _feeAmount.mul(IltERC20Price(ltPrice).getPrice()).div(10 ** 18);

            require(msg.value >= _btcFee, "Insufficient handling fee");
            (bool rsuccess, ) = payable(feeReceive).call{ value: _btcFee }("");
            if (!rsuccess) {
                revert();
            }
            uint256 _feeOver = msg.value - _btcFee;
            if (_feeOver > 21000) {
                (bool success, ) = payable(msg.sender).call{ value: _feeOver }("");
                if (!success) {
                    revert();
                }
            }
        }
    }

    function withdrawTokensSelf(address token, address to) external onlyAssetManager {
        require(to != address(0), "Cannot be zero address");
        if (token == address(0)) {
            (bool success, ) = payable(to).call{ value: address(this).balance }("");
            if (!success) {
                revert();
            }
        } else {
            uint256 bal = IERC20(token).balanceOf(address(this));
            IERC20(token).safeTransfer(to, bal);
        }
        emit Withdraw(token, to);
    }

    function setWethFee(uint256 _in, uint256 _out) external onlyAdmin {
        wethInFee = _in;
        wethOutFee = _out;
        emit UpdateWethFee(_in, _out);
    }

    function setFee(uint256 _in, uint256 _out) external onlyAdmin {
        inFee = _in;
        outFee = _out;
        emit UpdateFee(_in, _out);
    }

    function setSwapRate(uint256 _rate) external onlyAdmin {
        require(_rate > 0, "Ratio must be greater than 0");
        uint256 prev = rate;
        rate = _rate;
        emit UpdateRate(prev, _rate);
    }
    function setConvertEnabled(bool _enabledIn, bool _enabledOut) external onlyOwner {
        enabledConvertIn = _enabledIn;
        enabledConvertOut = _enabledOut;
    }

    function setltPriceAddress(address ltPrice_) external onlyOwner {
        require(ltPrice_ != address(0), "Cannot be zero address");
        address prev = ltPrice;
        ltPrice = ltPrice_;
        emit UpdateltPrice(prev, ltPrice_);
    }

    function setFeeReceive(address feeReceive_) external onlyOwner {
        require(feeReceive_ != address(0), "Cannot be zero address");
        address prev = feeReceive;
        feeReceive = feeReceive_;
        emit UpdateFeeReceive(prev, feeReceive_);
    }

    function setAdmin(address admin_) external onlyOwner {
        require(admin_ != address(0), "Cannot be zero address");
        address prev = admin;
        admin = admin_;
        emit UpdateAdmin(prev, admin_);
    }

    function setAssetManager(address assetManager_) external onlyOwner {
        require(assetManager_ != address(0), "Cannot be zero address");
        address prev = assetManager;
        assetManager = assetManager_;
        emit UpdateAdmin(prev, assetManager_);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    event Received(address, uint256);

    event Withdraw(address token, address to);
    event UpdateWethFee(uint256 inFee, uint256 outFee);
    event UpdateFee(uint256 inFee, uint256 outFee);

    event UpdateRate(uint256 oldRate, uint256 newRate);
    event UpdateltPrice(address old, address newAddress);
    event UpdateFeeReceive(address old, address newAddress);

    event UpdateAdmin(address old, address newAddress);
    event UpdateAssetManager(address old, address newAddress);
}
