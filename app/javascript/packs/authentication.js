import ReactRailsUJS from "react_ujs";

const componentRequireContext = require.context("components/Authentication", true);
ReactRailsUJS.useContext(componentRequireContext);
