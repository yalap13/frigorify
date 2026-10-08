# List of changes

- I don't really like the current when not loading the structure from the json file. Is it possible to change the underlying code so that the final api looks a bit more like the api from the library zap ? I would like if possible to be able to, for example load an initial config from a json file, maybe only the stage config and lines config and then add the elements. This could maybe make it possible to add other contents using plain cetz.
- I'd like to be able to control the general style of the diagram, for example the padding between lines and the padding between components.
- Some changes for the circulators:
  - The arrows should not be closed arrows
  - There should be a way to have single or double junction circulators. In the case of double junction ones, the two circles should be touching and a rectangle should be used to show they are both part of the same physical component. I was thinking of using rect-around from cetz with 0 padding.
- The filters should show symbols instead of accronyms to show their type (low pass, high pass, band pass)
