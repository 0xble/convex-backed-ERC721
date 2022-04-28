const shell = require("shelljs");

module.exports = {
  providerOptions: {
    mnemonic: process.env.MNEMONIC,
  },
  skipFiles: ["test", "mock"],
};
