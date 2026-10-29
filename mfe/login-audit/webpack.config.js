const { merge } = require("webpack-merge");
const singleSpaDefaults = require("webpack-config-single-spa-react");

module.exports = (webpackConfigEnv, argv) => {
  const defaultConfig = singleSpaDefaults({
    orgName: "localfind",
    projectName: "login-audit",
    webpackConfigEnv,
    argv,
    outputSystemJS: true,
  });

  return merge(defaultConfig, {
    devServer: {
      host: "0.0.0.0",
      headers: {
        "Access-Control-Allow-Origin": "*",
      },
    },
  });
};
