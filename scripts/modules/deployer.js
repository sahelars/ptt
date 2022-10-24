module.exports = async function deployer(
  name,
  constructor = null,
  signer = null
) {
  const contract = name;
  var deployer;
  if (signer === null) {
    [deployer] = await ethers.getSigners();
  } else {
    deployer = signer;
  }
  console.log(`${contract} deployer : ${deployer.address} (EOA)`);
  const token = await ethers.getContractFactory(contract);
  var Token;
  if (constructor === null) {
    Token = await token.connect(deployer).deploy();
  } else {
    Token = await token.connect(deployer).deploy(constructor);
  }
  console.log(`${contract} deployed : ${Token.address} (Contract)`);
  return Token;
};
