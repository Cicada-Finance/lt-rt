// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;
import "@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol";
import "./utils/SafeMath.sol";
import "./utils/FixedPoint96.sol";
import "./utils/FullMath.sol";

contract ltERC20Price {
    using SafeMath for uint256;
    address public pool;
    address public ltToken;
    address public pool2;
    address public weth;

    constructor(address pool_, address _pool2, address _ltToken) {
        pool = pool_;
        pool2 = _pool2;
        ltToken = _ltToken;
    }

    function getPrice() external view returns (uint256) {
        uint128 amount = 1 * 10 ** 18;
        (uint256 out, ) = this.getAmountsOut(pool, amount, ltToken);
        (uint256 wethPrice, ) = this.getAmountsOut(pool2, amount, weth);
        return FullMath.mulDiv(out, 10 ** 18, wethPrice);
    }
    function getAmountsOut(
        address _pool,
        uint256 amountIn,
        address tokenIn
    ) public view returns (uint256 outAmount, uint160 sqrtPriceX96) {
        IUniswapV3Pool IPool = IUniswapV3Pool(_pool);
        (sqrtPriceX96, , , , , , ) = IPool.slot0();
        bool zeroForOne = tokenIn == IPool.token0();

        uint256 priceSquared;
        if (zeroForOne) {
            priceSquared = FullMath.mulDiv(
                FixedPoint96.Q96,
                FixedPoint96.Q96,
                FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96)
            );
        } else {
            priceSquared = FullMath.mulDiv(sqrtPriceX96, sqrtPriceX96, FixedPoint96.Q96);
        }

        outAmount = FullMath.mulDiv(amountIn, FixedPoint96.Q96, priceSquared);

        require(outAmount != 0, "Output Zero");
        return (outAmount, sqrtPriceX96);
    }
}
