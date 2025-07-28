# StageRaise - Decentralized Crowdfunding Platform

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Solidity](https://img.shields.io/badge/Solidity-^0.8.20-green.svg)
![Foundry](https://img.shields.io/badge/Built%20with-Foundry-orange.svg)

StageRaise is a decentralized crowdfunding platform that enables milestone-based project funding with community governance and voting mechanisms.

## 🌟 Features

### Core Features
- **Project Creation**: Create crowdfunding projects with customizable parameters
- **Flexible Funding**: Support for both milestone-based and traditional funding models
- **USD-Based Limits**: Set minimum and maximum funding amounts in USD using Chainlink price feeds
- **Community Voting**: Funders can vote on milestone completion for milestone-based projects
- **Refund System**: Manual refund claims available for failed milestone-based projects
- **Proportional Withdrawals**: Project owners can withdraw funds based on completed milestones

### Key Capabilities
- **Real-time ETH/USD Price Integration**: Uses Chainlink oracles for accurate USD conversions
- **Voting Power**: Voting power is proportional to the amount funded by each contributor
- **Deadline Management**: Automatic project deactivation after funding deadlines

## 🏗️ Project Structure

```
├── src/
│   └── StageRaise.sol          # Main contract implementation
├── script/
│   ├── DeployStageRaise.s.sol  # Deployment script
│   └── HelperConfig.s.sol      # Network configuration helper
├── test/
│   ├── uint/
│   │   └── StageRaise.t.sol    # Unit tests
│   ├── integration/
│   │   └── StageRaiseIntegration.t.sol  # Integration tests
│   └── mocks/
│       └── MockV3Aggregator.sol # Mock price feed for testing
├── lib/                        # Dependencies (Forge Standard Library, Chainlink)
├── foundry.toml               # Foundry configuration
├── Makefile                   # Build and test commands
└── README.md                  # This file
```

## 🚀 Getting Started

### Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation)
- [Git](https://git-scm.com/)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Trynax/Stage-raise.git
   cd Stage-raise
   ```

2. **Install dependencies**
   ```bash
   make install
   ```

3. **Build the project**
   ```bash
   make build
   ```

4. **Run tests**
   ```bash
   make test
   ```

### Environment Setup

Create a `.env` file in the root directory:
```env
SEPOLIA_RPC_URL=your_sepolia_rpc_url
MAINNET_RPC_URL=your_mainnet_rpc_url
```

## 📖 How It Works

### Project Types

**1. Traditional Projects**
- Simple crowdfunding with a target amount and deadline
- Project owner can withdraw all funds after the deadline
- No milestone requirements or voting

**2. Milestone-Based Projects**
- Funds are released based on milestone completion
- Community votes on milestone achievements
- Manual refund claims available if too many milestones fail (3+ failures)
- Proportional fund release (e.g., 20% per milestone for 5-milestone project)

### Project Lifecycle

1. **Creation**: Project owner creates a project with parameters:
   - Name and description
   - Target funding amount (in ETH)
   - Funding deadline
   - USD-based min/max funding limits per contributor
   - Milestone configuration (if applicable)

2. **Funding Phase**: 
   - Contributors fund the project with ETH
   - Funding limits enforced based on USD value
   - Automatic deactivation after deadline

3. **Milestone Voting** (for milestone projects):
   - Project owner opens voting for milestone completion
   - Funders vote with power proportional to their contribution
   - Voting period has a time limit

4. **Fund Withdrawal**:
   - Traditional projects: Full withdrawal after deadline
   - Milestone projects: Proportional withdrawal based on completed milestones

5. **Refund Process** (if applicable):
   - Available for milestone projects that fail 3+ milestones
   - Funders must manually claim their proportional refunds
   - Refunds are calculated based on remaining project balance

### Key Parameters

- **Target Amount**: Total funding goal in ETH
- **Deadline**: Timestamp when funding closes
- **Min/Max Funding USD**: Per-contributor limits in USD (8 decimals)
- **Milestone Count**: Number of milestones for milestone-based projects
- **Voting Period**: Duration for milestone voting processes

## 🛠️ Usage Examples

### Creating a Project

```solidity
// Traditional project
stageRaise.createProject(
    StageRaise.CreateProjectParams({
        name: "My Awesome Project",
        description: "Building something amazing",
        targetAmount: 10 ether,
        deadline: block.timestamp + 30 days,
        milestoneCount: 0,
        milestoneBased: false,
        timeForMileStoneVotingProcess: 0,
        minFundingUSD: 100e8,    // $100 minimum
        maxFundingUSD: 10000e8   // $10,000 maximum
    })
);

// Milestone-based project
stageRaise.createProject(
    StageRaise.CreateProjectParams({
        name: "Milestone Project",
        description: "Project with community oversight",
        targetAmount: 20 ether,
        deadline: block.timestamp + 60 days,
        milestoneCount: 5,
        milestoneBased: true,
        timeForMileStoneVotingProcess: 7 days,
        minFundingUSD: 500e8,    // $500 minimum
        maxFundingUSD: 50000e8   // $50,000 maximum
    })
);
```

### Funding a Project

```solidity
// Fund with 2 ETH
stageRaise.fundProject{value: 2 ether}(projectId);
```

### Milestone Voting

```solidity
// Project owner opens voting
stageRaise.openProjectForMilestoneVotes(projectId);

// Funders vote (true = milestone completed, false = not completed)
stageRaise.takeAVoteForMilestoneStageIncrease(projectId, true);

// Anyone can finalize voting after the voting period
stageRaise.finalizeVotingProcess(projectId);
```

### Requesting Refunds (Failed Milestone Projects)

```solidity
// Check if refund is available (project must have failed 3+ milestones)
uint256 failedMilestones = stageRaise.getProjectFailedMilestoneStage(projectId);

// Request refund (funders must call this manually)
stageRaise.requestRefund(projectId);
```

### Withdrawing Funds

```solidity
// Check withdrawable amount
uint256 withdrawable = stageRaise.getAmountWithdrawableForAProject(projectId);

// Withdraw funds (project owner only)
stageRaise.withdrawFunds(withdrawable, projectId, payable(msg.sender));
```

## 🧪 Testing

The project includes comprehensive tests:

- **Unit Tests**: Test individual functions and edge cases
- **Integration Tests**: Test complete project lifecycles
- **Fork Tests**: Test against live networks

### Run Tests

```bash
# All tests
make test

# Unit tests only
make test-unit

# Integration tests only
make test-integration

# Fork tests (requires RPC URL)
make test-fork-sepolia

make test-fork-mainnet

# Coverage report
make coverage
```

## 📊 Contract Architecture

### Main Contract: `StageRaise.sol`

**Key Structs:**
- `ProjectBasics`: Core project information
- `ProjectMilestone`: Milestone and voting data
- `Project`: Complete project state
- `CreateProjectParams`: Project creation parameters

**Key Functions:**
- `createProject()`: Create new crowdfunding projects
- `fundProject()`: Contribute ETH to projects
- `openProjectForMilestoneVotes()`: Start milestone voting
- `takeAVoteForMilestoneStageIncrease()`: Vote on milestones
- `withdrawFunds()`: Withdraw funds (project owners)
- `requestRefund()`: Request refunds (failed milestone projects)

**View Functions:**
- `getProjectBasicInfo()`: Get project details
- `getAmountWithdrawableForAProject()`: Calculate withdrawable amount
- `calculateFunderVotingPower()`: Get voting power
- Various getter functions for project state

### Helper Contracts

- **HelperConfig**: Network-specific configuration
- **MockV3Aggregator**: Price feed mock for testing

## 🔧 Development

### Available Commands (Makefile)

```bash
make build          # Compile contracts
make clean          # Clean build artifacts
make install        # Install dependencies
make test           # Run all tests
make test-unit      # Run unit tests
make test-integration # Run integration tests
make test-fork      # Run fork tests
make coverage       # Generate coverage report
make anvil          # Start local Anvil node
make format         # Format code
```

### Network Support

- **Mainnet**: Uses Chainlink ETH/USD price feed
- **Sepolia**: Uses Chainlink ETH/USD price feed
- **Local/Anvil**: Uses mock price feed

## 🔒 Security Features

- **Access Control**: Owner-only functions for project management
- **Input Validation**: Comprehensive parameter validation
- **Deadline Enforcement**: Automatic project deactivation
- **Balance Checks**: Prevents over-withdrawal and invalid transfers
- **Voting Integrity**: Prevents double voting and enforces voting periods
- **USD Limits**: Real-time price feed integration for accurate limits

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## 📞 Contact

- **Author**: [Trynax](https://github.com/Trynax)
- **X**:[@trynaxPrmr](https://x.com/TrynaxPRMR)
- **Repository**: [Stage-raise](https://github.com/Trynax/Stage-raise)

## 🔮 Future Enhancements

### Planned Features

- **Stablecoin Support**: Accept USDC, USDT, DAI for more stable funding instead of just ETH
- **Project Categories & Tags**: Organize projects by type (DeFi, Gaming, NFTs, etc.) to help funders discover relevant projects
- **Better Voting System**: Improved voting mechanisms and governance tokens for platform decisions
- **IPFS Integration**: Store project documentation, images, and updates on decentralized storage instead of just on-chain text
- **Complete Web Application**: Build both frontend (user interface) and backend (server) for easy interaction without technical knowledge
- **Analytics Dashboard**: Show funding trends, success rates, popular project types, and other platform statistics

---

**Built with ❤️ using Foundry and Solidity**
