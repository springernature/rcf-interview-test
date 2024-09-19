/*

	This is the main entry point for the RCF challenge.

	we need to:

	1. get a list of activities with gradableType 'closed-gradable' from the manifest.json file

	2. populate the `#activities` div with the list of activities

	3. when an activity is clicked, load the activity html into the `#activity-contents` div

	4. call the RCF.Application.updateContent() method passing in the activity-contents *element*

	5. The RCF.Application.updateContent() method will update the content of the element passed in with the RCF components

	The call to RCF.Application.updateContent requires a **jquery** wrapped html element (not a raw html element) - this is
	because the RCF library used here is an older version - newer versions do not have that restriction)

	eg.
	```
	RCF.Application.updateContent( $(activityElement) );
	```

	NOTE!

	Both RCF and jQuery are registered as global variables on the global window object and will be available
	to use in this file (they are loaded in the index.html file

*/

// the 'fetch' location for our html / json files
const CDN_URL = '/cdn/projects/rcf-sandbox/1.0.0/Level_PBF_auto_test/';

document.addEventListener('DOMContentLoaded', async () => {
	// initialise RCF - it's registered on the window object as a global variable
	RCF.Application.initialize({});

	// TO DO....

	// 1. get a list of activities with gradableType 'closed-gradable' from the manifest.json file
	// 2. populate the #activities div with the list of activities
	// 3. when an activity is clicked, load the activity html into the #activity-contents div
	// 4. call the RCF.Application.updateContent() method passing in the activity-contents *element*
});
