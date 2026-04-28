// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract HoverMarkets {
    uint256 public marketCount;

    enum Outcome { Pending, Yes, No }

    struct Market {
        address creator;
        string question;
        uint256 deadline;
        bool resolved;
        Outcome outcome;
        uint256 totalYesPool;
        uint256 totalNoPool;
    }

    mapping(uint256 => Market) public markets;
    // marketId => (user => amount)
    mapping(uint256 => mapping(address => uint256)) public yesBets;
    mapping(uint256 => mapping(address => uint256)) public noBets;
    mapping(uint256 => mapping(address => bool)) public hasClaimed;

    event MarketCreated(uint256 indexed marketId, address indexed creator, string question, uint256 deadline);
    event BetPlaced(uint256 indexed marketId, address indexed better, bool isYes, uint256 amount);
    event MarketResolved(uint256 indexed marketId, bool finalOutcome);
    event WinningsClaimed(uint256 indexed marketId, address indexed winner, uint256 amount);

    function createMarket(string memory _question, uint256 _durationInSeconds) external returns (uint256) {
        require(_durationInSeconds > 0, "Duration must be > 0");

        marketCount++;
        uint256 marketId = marketCount;
        uint256 deadline = block.timestamp + _durationInSeconds;

        markets[marketId] = Market({
            creator: msg.sender,
            question: _question,
            deadline: deadline,
            resolved: false,
            outcome: Outcome.Pending,
            totalYesPool: 0,
            totalNoPool: 0
        });

        emit MarketCreated(marketId, msg.sender, _question, deadline);
        return marketId;
    }

    function placeBet(uint256 _marketId, bool _isYes) external payable {
        require(msg.value > 0, "Must bet more than 0");
        Market storage market = markets[_marketId];
        require(market.creator != address(0), "Market does not exist");
        require(block.timestamp < market.deadline, "Market deadline has passed");
        require(!market.resolved, "Market already resolved");

        if (_isYes) {
            market.totalYesPool += msg.value;
            yesBets[_marketId][msg.sender] += msg.value;
        } else {
            market.totalNoPool += msg.value;
            noBets[_marketId][msg.sender] += msg.value;
        }

        emit BetPlaced(_marketId, msg.sender, _isYes, msg.value);
    }

    function resolveMarket(uint256 _marketId, bool _finalOutcome) external {
        Market storage market = markets[_marketId];
        require(market.creator != address(0), "Market does not exist");
        require(msg.sender == market.creator, "Only creator can resolve");
        require(block.timestamp >= market.deadline, "Deadline not reached yet");
        require(!market.resolved, "Already resolved");

        market.resolved = true;
        market.outcome = _finalOutcome ? Outcome.Yes : Outcome.No;

        emit MarketResolved(_marketId, _finalOutcome);
    }

    function claimWinnings(uint256 _marketId) external {
        Market storage market = markets[_marketId];
        require(market.resolved, "Market not resolved yet");
        require(!hasClaimed[_marketId][msg.sender], "Already claimed");

        uint256 userBet;
        uint256 winningPool;
        uint256 losingPool;

        if (market.outcome == Outcome.Yes) {
            userBet = yesBets[_marketId][msg.sender];
            winningPool = market.totalYesPool;
            losingPool = market.totalNoPool;
        } else if (market.outcome == Outcome.No) {
            userBet = noBets[_marketId][msg.sender];
            winningPool = market.totalNoPool;
            losingPool = market.totalYesPool;
        } else {
            revert("Invalid outcome");
        }

        require(userBet > 0, "No winning bet found");
        hasClaimed[_marketId][msg.sender] = true;

        // Calculate reward: user's bet + proportional share of the losing pool
        uint256 reward = userBet;
        if (losingPool > 0 && winningPool > 0) {
            reward += (userBet * losingPool) / winningPool;
        }

        (bool success, ) = payable(msg.sender).call{value: reward}("");
        require(success, "Transfer failed");

        emit WinningsClaimed(_marketId, msg.sender, reward);
    }
}
