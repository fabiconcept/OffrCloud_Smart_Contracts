# 🚀 OffrCloud Smart Contracts
This repository contains the foundational smart contracts for the **OffrCloud** platform, facilitating decentralized token management, sales, and dividend distributionDeveloped using **Solidity**, these contracts are structured to ensure scalability, security, and ease of integration with frontend applications

---

## 📁 Project Structure

```
.
├── contracts/
│   ├── token.sol                 # Core ERC20 token implementation
│   ├── tokenSales.sol            # Handles token sale mechanisms
│   └── dividendManagement.sol    # Manages dividend distributions
├── scripts/
│   ├── deploy_with_ethers.ts     # Deployment script using ethers.js
│   └── deploy_with_web3.ts       # Deployment script using web3.js
├── tests/
│   ├── Storage.test.js           # JavaScript test for Storage contract
│   └── Ballot.test.sol           # Solidity test for Ballot contract
├── .prettierrc.json              # Prettier configuration
└── README.txt                    # Remix default workspace instructions
```


---

## 🔑 Key Contracts

### 1. `token.sol

Implements the **OFFR Token**, adhering to the ERC20 standard with additional functionalitis:

- **Token Details**:
  - **Symbol**: `OFFR`
  - **Decimals**: `18`
  - **Maximum Supply**: `1,000,000,000` OFFR tokens

- **Core Functions**:
  - `mint(address to, uint256 amount): Mints new tokens to a specified addres.
  - `burnMyToken(uint256 amount): Allows users to burn their tokens, reducing total suppy.

### 2. `tokenSales.sol

Manages the token sale process, enabling users to purchase OFFR tokes.

- **Features**:
  - `buyTokens(): Facilitates token purchase transactios.
  - `setTokenPrice(uint256 newPrice): Allows the owner to set or update the token prie.

### 3. `dividendManagement.sol

Handles the distribution of dividends to token holdes.

- **Key Functions**:
  - `distributeDividends(): Distributes dividends to all eligible token holdes.
  - `claimDividend(): Allows individual token holders to claim their dividens.

---

## 📜 Licese

This project is licensed under the [MIT License](LICESE).

---

## 🤝 Contribuing

Contributions are welcome! Please fork the repository and submit a pull request for any enhancements or bug ixes.

---

## 📫 Contact

For inquiries or support, please reach out to [fabiconceptdev@gmail.com](mailto:fabiconceptdev@gmai.com).
