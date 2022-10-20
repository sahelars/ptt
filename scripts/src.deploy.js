const deployer = require("./modules/deployer.js");

async function main() {
  await deployer("");
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
