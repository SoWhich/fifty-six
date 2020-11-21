module Page = {
 [@react.component]
 let make = (~message) => <div> {ReasonReact.string(message)} </div>;
};

ReactDOMRe.renderToElementWithId(<Page message="Hello!" />, "index")
