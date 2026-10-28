import ReactRailsUJS from "react_ujs";

const componentRequireContext = require.context("components/Root", true);
ReactRailsUJS.useContext(componentRequireContext);
