# 📝 Public Petition Smart Contract

A decentralized petition system built on the Stacks blockchain that enables citizens to create, sign, and manage verified on-chain petitions for real-world issues.

## 🌟 Features

- ✅ **Create Petitions**: Citizens can initiate petitions with customizable targets and durations
- 🖊️ **Digital Signatures**: Secure on-chain petition signing with verification
- ⏰ **Time-bound Petitions**: Automatic expiration system for petition validity
- 📊 **Progress Tracking**: Real-time monitoring of signature collection progress
- 🔐 **Verification System**: Contract owner can verify signatures for authenticity
- 📈 **Analytics**: Track petition success rates and user participation

## 🚀 Getting Started

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet) installed
- Stacks wallet for testing

### Installation

```bash
clarinet new petition-project
cd petition-project
```

Copy the contract code into `contracts/Public-Petition-Smart-Contract.clar`

### Testing

```bash
clarinet console
```

## 📖 Usage

### Creating a Petition

```clarity
(contract-call? .Public-Petition-Smart-Contract create-petition 
  "Save Local Park" 
  "Petition to prevent the demolition of Central Park for commercial development" 
  u1000 
  u4320 
  "Environment")
```

### Signing a Petition

```clarity
(contract-call? .Public-Petition-Smart-Contract sign-petition u1)
```

### Checking Petition Status

```clarity
(contract-call? .Public-Petition-Smart-Contract get-petition-status u1)
```

### Viewing Petition Details

```clarity
(contract-call? .Public-Petition-Smart-Contract get-petition u1)
```

## 🔧 Contract Functions

### Public Functions

| Function | Description | Parameters |
|----------|-------------|------------|
| `create-petition` | Create a new petition | title, description, target-signatures, duration-blocks, category |
| `sign-petition` | Sign an existing petition | petition-id |
| `deactivate-petition` | Deactivate a petition (creator only) | petition-id |
| `verify-signature` | Verify a signature (owner only) | petition-id, signer |

### Read-Only Functions

| Function | Description | Returns |
|----------|-------------|---------|
| `get-petition` | Get petition details | Petition data |
| `get-petition-status` | Get petition status | Status object |
| `get-petition-progress` | Get signature progress | Progress metrics |
| `has-user-signed` | Check if user signed | Boolean |
| `is-petition-expired` | Check if petition expired | Boolean |

## 🏗️ Contract Architecture

### Data Structures

- **Petitions Map**: Stores petition metadata and current state
- **Signatures Map**: Tracks individual petition signatures
- **User Counters**: Maintains user petition creation statistics
- **Signers Lists**: Stores petition signer addresses

### Error Codes

- `u100`: Unauthorized access
- `u101`: Petition not found
- `u102`: Petition expired
- `u103`: Already signed
- `u104`: Invalid duration
- `u105`: Petition inactive
- `u106`: Invalid target

## 🔒 Security Features

- ✅ Signature uniqueness enforcement
- ✅ Time-based petition expiration
- ✅ Creator-only petition management
- ✅ Owner-based signature verification
- ✅ Input validation and sanitization

## 🎯 Use Cases

- 🏛️ **Civic Engagement**: Local government policy changes
- 🌱 **Environmental Issues**: Conservation and sustainability initiatives  
- 🏫 **Community Projects**: School funding and local infrastructure
- ⚖️ **Social Justice**: Human rights and equality campaigns
- 🏥 **Public Health**: Healthcare access and safety measures

## 📊 Example Workflow

1. **Citizen** creates petition for local issue
2. **Community** discovers and signs petition
3. **Signatures** accumulate toward target goal
4. **Progress** tracked transparently on-chain
5. **Results** used to demonstrate public support

## 🤝 Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Commit changes (`git commit -m 'Add amazing feature'`)
4. Push to branch (`git push origin feature/amazing-feature`)
5. Open Pull Request

## 📄 License

This project is licensed under the MIT License - see the LICENSE file for details.

## 🙋‍♀️ Support

For questions and support, please open an issue in the GitHub repository.

---

*Built with ❤️ for transparent democracy on Stacks blockchain*
```

## Git Commit Message

```
feat: implement public petition smart contract with signature verification system
```

## GitHub Pull Request Title

```
🗳️ Add Public Petition Smart Contract - Decentralized Civic Engagement Platform
```

## GitHub Pull Request Description

```markdown
## Summary
This PR introduces a comprehensive public petition smart contract that enables decentralized civic engagement on the Stacks blockchain.

## ✨ What's Added
- **Complete petition lifecycle management** - create, sign, track, and verify petitions
- **Time-bound petition system** with automatic expiration handling
- **Signature verification mechanism** for authenticity assurance
- **Progress tracking and analytics** for real-time petition monitoring
- **Multi-category support** for organizing different types of civic issues
- **User participation tracking** with signature history and statistics

## 🔧 Technical Features
- Robust error handling with comprehensive error codes
- Gas-optimized data structures using efficient maps
- Security measures preventing duplicate signatures and unauthorized access
- Read-only functions for transparent petition data access
- Owner-controlled verification system for signature authenticity

## 📋 Contract Capabilities
- Citizens can create petitions with custom targets and durations
- Community members can securely sign petitions on-chain
- Real-time progress tracking toward signature goals
- Petition creators can manage their initiatives
- Contract owner can verify signatures for enhanced credibility

## 🧪 Testing
- All functions tested for proper execution
- Error conditions validated
- Edge cases handled appropriately
- Gas optimization verified

This implementation provides a solid foundation for transparent, verifiable civic engagement through blockchain technology.
