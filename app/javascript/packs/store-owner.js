import ReactRailsUJS from "react_ujs";

const componentRequireContext = require.context("components/StoreOwner", true);
ReactRailsUJS.useContext(componentRequireContext);
