import ReactRailsUJS from "react_ujs";

const componentRequireContext = require.context("components/Admin", true);
ReactRailsUJS.useContext(componentRequireContext);
