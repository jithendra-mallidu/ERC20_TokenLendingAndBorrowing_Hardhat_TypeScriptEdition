// SPDX-License-Identifier: MIT
pragma solidity >=0.4.22 <0.9.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LendingAndBorrowing is Ownable {
    mapping(address => mapping(address => uint256)) public tokensLentAmount;
    mapping(address => mapping(address => uint256)) public tokensBorrowedAmount;
    mapping(address => uint256) public tokensCollateralAmount;
    mapping(address => uint256) public collateralLocked;

    address tokenAsCollateral;

    struct Token {
        address tokenAddress;
        string name;
    }

    Token[] public tokensForLending;
    Token[] public tokensForBorrowing;

    event TokenAddedInLendingList(string name, address tokenAddress);
    event TokenAddedInBorrowingList(string name, address tokenAddress);
    event TokensLended(
        address tokenAddres,
        uint256 amount,
        address lendersAddress
    );
    event TokensWithdrawn(
        address tokenAddres,
        uint256 amount,
        address lendersAddress
    );
    event CollateralDeposited(uint256 amount, address user);
    event TokensBorrowed(
        address tokenAddress,
        uint256 amount,
        address whoBorrowed
    );
    event DebtPaidBack(
        address tokenAddress,
        uint256 amount,
        address whoPaidBack
    );
    event CollateralReleased(uint256 amount, address user);

    //Using this function admin can add/list new token into pool.
    function addTokensForLending(
        string memory name,
        address tokenAddress
    ) public onlyOwner {
        Token memory token = Token(tokenAddress, name);

        if (!tokenIsAlreadyThere(token, tokensForLending)) {
            tokensForLending.push(token);
        }

        emit TokenAddedInLendingList(name, tokenAddress);
    }

    //Using this function admin can list/add new token into Borrow pool.
    function addTokensForBorrowing(
        string memory name,
        address tokenAddress
    ) public onlyOwner {
        Token memory token = Token(tokenAddress, name);
        if (!tokenIsAlreadyThere(token, tokensForBorrowing)) {
            tokensForBorrowing.push(token);
        }
        emit TokenAddedInBorrowingList(name, tokenAddress);
    }

    // Function To Change Collateral Token
    function tokenCollateral(address tokenAddress) public onlyOwner {
        tokenAsCollateral = tokenAddress;
    }

    // Function to view Lending Array
    function getTokensForLendingArray() public view returns (Token[] memory) {
        return tokensForLending;
    }

    // Function to view borrow Array
    function getTokensForBorrowingArray() public view returns (Token[] memory) {
        return tokensForBorrowing;
    }

    //To Lend -- Function to lend tokens into the contract
    function toLend(address tokenAddress, uint256 amount) public {
        require(
            tokenIsAllowed(tokenAddress, tokensForLending),
            "Token is not supported!"
        );
        require(
            amount > 0,
            "The amount to supply should be greater than zero!"
        );
        IERC20 token = IERC20(tokenAddress);
        require(
            token.balanceOf(msg.sender) >= amount,
            "You dont have enough balance to deposit!"
        );
        require(
            token.allowance(msg.sender, address(this)) >= amount,
            "Not enough allowance!"
        );
        tokensLentAmount[tokenAddress][msg.sender] += amount;
        token.transferFrom(msg.sender, address(this), amount);
        emit TokensLended(tokenAddress, amount, msg.sender);
    }

    //To Withdraw -- Function to withdraw what you have lent to the contract
    function toWithdrawLentTokens(address tokenAddress, uint256 amount) public {
        require(amount > 0, "Amount to withdraw should be greater than zero!");
        IERC20 token = IERC20(tokenAddress);
        require(
            amount <= token.balanceOf(address(this)),
            "Pool doesnt have enough balance!"
        );
        uint256 availableToWithdraw = tokensLentAmount[tokenAddress][
            msg.sender
        ];
        require(
            amount <= availableToWithdraw,
            "You dont have enough balance to withdraw this much of tokens!"
        );
        tokensLentAmount[tokenAddress][msg.sender] -= amount;
        token.transfer(msg.sender, amount);
        emit TokensWithdrawn(tokenAddress, amount, msg.sender);
    }

    function tokenIsAllowed(
        address tokenAddress,
        Token[] memory tokenArray
    ) private pure returns (bool) {
        if (tokenArray.length > 0) {
            for (uint256 i = 0; i < tokenArray.length; i++) {
                Token memory currentToken = tokenArray[i];
                if (currentToken.tokenAddress == tokenAddress) {
                    return true;
                }
            }
        }
        return false;
    }

    //This function is to check if the token is already present in the tokenArray.
    function tokenIsAlreadyThere(
        Token memory token,
        Token[] memory tokenArray
    ) private pure returns (bool) {
        if (tokenArray.length > 0) {
            for (uint256 i = 0; i < tokenArray.length; i++) {
                Token memory currentToken = tokenArray[i];
                if (currentToken.tokenAddress == token.tokenAddress) {
                    return true;
                }
            }
        }
        return false;
    }

    //You need to deposit 1USDT token to borrow 1 token from the pool.
    //Deposit Collateral
    function depositCollateral(uint256 amount) public {
        require(amount > 0, "Amount should be greater than zero!");
        require(
            IERC20(tokenAsCollateral).balanceOf(msg.sender) >= amount,
            "You dont have enough balance!"
        );

        require(
            IERC20(tokenAsCollateral).transferFrom(
                msg.sender,
                address(this),
                amount
            )
        );
        tokensCollateralAmount[msg.sender] += amount;

        emit CollateralDeposited(amount, msg.sender);
    }

    function borrow(uint256 amount, address tokenAddress) public {
        require(
            tokenIsAllowed(tokenAddress, tokensForBorrowing),
            "Token is not supported for borrowing!"
        );

        require(amount > 0, "Amount should be greater than zero!");

        require(
            tokensCollateralAmount[msg.sender] - collateralLocked[msg.sender] >=
                amount,
            "You dont have enough collateral to borrow this amount!"
        );

        IERC20 token = IERC20(tokenAddress);

        require(
            token.balanceOf(address(this)) >= amount,
            "Pool doesnt have enough balance!"
        );

        tokensBorrowedAmount[tokenAddress][msg.sender] += amount;
        collateralLocked[msg.sender] += amount;
        token.transfer(msg.sender, amount);

        emit TokensBorrowed(tokenAddress, amount, msg.sender);
    }

    //To pay Debt
    function payDebt(address tokenAddress, uint256 amount) public {
        require(
            tokenIsAllowed(tokenAddress, tokensForBorrowing),
            "Token is not supported for borrowing!"
        );

        require(amount > 0, "Amount should be greater than zero!");

        require(
            IERC20(tokenAddress).balanceOf(msg.sender) >= amount,
            "You dont have enough balance!"
        );

        require(
            tokensBorrowedAmount[tokenAddress][msg.sender] != 0,
            "You dont have any debt!"
        );
        require(
            tokensBorrowedAmount[tokenAddress][msg.sender] >= amount,
            " You are paying more than you borrowed!"
        );

        IERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        tokensBorrowedAmount[tokenAddress][msg.sender] -= amount;
        collateralLocked[msg.sender] -= amount;

        emit DebtPaidBack(tokenAddress, amount, msg.sender);
    }

    //Release Collateral
    function releaseCollateral(uint256 amount) public {
        require(amount > 0, "Amount should be greater than zero!");

        require(
            tokensCollateralAmount[msg.sender] - collateralLocked[msg.sender] >=
                amount,
            "Your collateral is locked due to debt or you dont have any collateral!"
        );

        IERC20(tokenAsCollateral).transfer(msg.sender, amount);
        tokensCollateralAmount[msg.sender] -= amount;

        emit CollateralReleased(amount, msg.sender);
    }
}
