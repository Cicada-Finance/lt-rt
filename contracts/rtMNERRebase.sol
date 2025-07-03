// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@uniswap/swap-router-contracts/contracts/interfaces/ISwapRouter02.sol";
import "./utils/Ownable.sol";
import "./interface/IrtERC20.sol";
import "./utils/SafeMath.sol";
import "./utils/TransferHelper.sol";

contract rtMNERRebase is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    ISwapRouter02 public immutable router;

    address public immutable tokenB;

    address public immutable rtToken;

    address public immutable convert;
    address public admin;
    bytes public path;
    uint256 public nextTime;
    uint256 public maxOutAmount = 500 * 1e18;

    error AmountInvalid();

    modifier onlyAdmin() {
        require(msg.sender == admin, "permissions error");
        _;
    }

    constructor(
        address _admin,
        address _router,
        address _rtToken,
        address _tokenB,
        address _convert,
        bytes memory path_
    ) Ownable(msg.sender) {
        require(_convert != address(0), "Cannot be zero address");
        require(_rtToken != address(0), "Cannot be zero address");

        rtToken = _rtToken;
        path = path_;
        convert = _convert;
        admin = _admin;
        router = ISwapRouter02(_router);
        tokenB = _tokenB;
    }

    function swapAndRebase(uint128 amountIn, uint128 amountOutMinimum) public payable onlyAdmin {
        require(nextTime < block.timestamp, "Operating too quickly");

        IERC20(tokenB).safeTransferFrom(msg.sender, address(this), amountIn);
        TransferHelper.safeApprove(tokenB, address(router), amountIn);

        IV3SwapRouter.ExactInputParams memory params = IV3SwapRouter.ExactInputParams({
            path: path,
            recipient: convert,
            amountIn: amountIn,
            amountOutMinimum: amountOutMinimum
        });

        uint256 amountOut = router.exactInput(params);

        if (amountOut == 0 || amountOut > maxOutAmount) {
            revert AmountInvalid();
        }
        nextTime = block.timestamp + 300;
        IrtERC20(rtToken).rebase(int256(amountOut));
        emit SwapAndRebase(amountIn, amountOut);
    }

    function withdrawTokensSelf(address token, address to) external onlyOwner {
        require(to != address(0), "Address cannot be zero");
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

    function setAdmin(address admin_) external onlyOwner {
        require(admin_ != address(0), "Cannot be zero address");
        address prev = admin;
        admin = admin_;
        emit UpdateAdmin(prev, admin_);
    }

    function setMaxAmount(uint256 _max) external onlyOwner {
        uint256 prev = maxOutAmount;
        maxOutAmount = _max;
        emit UpdateMaxAmount(prev, _max);
    }

    receive() external payable {
        emit Received(msg.sender, msg.value);
    }

    event Received(address, uint256);
    event UpdateMaxAmount(uint256 pre, uint256 next);
    event Withdraw(address token, address to);
    event UpdateAdmin(address pre, address next);
    event SwapAndRebase(uint128 amountIn, uint256 amountOut);
}
