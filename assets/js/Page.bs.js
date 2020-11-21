'use strict';

var React = require("react");
var ReactDOMRe = require("reason-react/src/legacy/ReactDOMRe.bs.js");

function Page$Page(Props) {
  var message = Props.message;
  return React.createElement("div", undefined, message);
}

var Page = {
  make: Page$Page
};

ReactDOMRe.renderToElementWithId(React.createElement(Page$Page, {
          message: "Hello!"
        }), "index");

exports.Page = Page;
/*  Not a pure module */
