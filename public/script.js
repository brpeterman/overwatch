/*
  Displays the section corresponding to the tab the user clicked on and hides whatever was active before.
*/
function selectTab(tab) {
    var tabs = document.getElementsByClassName("statusline");
    for (var i = 0; i < tabs.length; i++) {
	tabs[i].classList.remove("selected");
    }
    var activeTab = document.getElementById(tab + "-status");
    activeTab.classList.add("selected");

    var sections = document.getElementsByClassName("section");
    for (var i = 0; i < sections.length; i++) {
	sections[i].classList.remove("selected");
    }
    var activeSection = document.getElementById(tab + "-section");
    activeSection.classList.add("selected");
}

/*
  Show/hide the Minecraft map
*/
function toggleMap() {
    var mapElem = document.getElementById("map-frame");
    var linkElem = document.getElementById("toggle-map");
    if (mapElem.style.display == "block") {
	mapElem.style.display = "none";
	linkElem.innerHTML = "Show Map";
    }
    else {
	mapElem.style.display = "block";
	linkElem.innerHTML = "Hide Map";
    }
}

/*
  Make sure everything is the right size
*/
function resize() {
    var sections = document.getElementsByClassName("section");
    var rect = sections[0].getBoundingClientRect();
    var browserHeight = document.documentElement.clientHeight;
    for (var i = 0; i < sections.length; i++) {
	sections[i].style.height = (browserHeight - rect.top - 15) + "px";
    }
}

/*
  EventSource message handler
  Updates the status of whatever servers it knows about with the latest information.
*/
function updateStatus(e) {
    if (!e.data) { return; }
    var status = JSON.parse(e.data);
    for (var key in status) {
	var tabElem = document.getElementById(key + "-status")
	if (tabElem) {
	    var statusElem = tabElem.querySelector(".status")
	    if (status[key]["online"]) {
		statusElem.classList.remove("offline");
		statusElem.classList.add("online");
		statusElem.innerHTML = "Online";
	    }
	    else {
		statusElem.classList.remove("online");
		statusElem.classList.add("offline");
		statusElem.innerHTML = "Offline";
	    }
	    var countElem = tabElem.querySelector(".player-count");
	    if (countElem) {
		countElem.innerHTML = "(" + status[key]["player count"] + ")";
	    }
	}
	var serverStatus = status[key];
	var sectionElem = document.getElementById(key + "-section");
	if (sectionElem) {
	    for (var field in serverStatus) {
		var selector = "." + field.replace(' ', '_') + "-value";
		var valueElem = sectionElem.querySelector(selector);
		if (valueElem) {
		    if (field == "player list") {
			if (serverStatus[field] == "") {
			    serverStatus[field] = "None";
			}
			else {
			    serverStatus[field] = serverStatus[field].join(', ');
			}
		    }
		    valueElem.innerHTML = serverStatus[field];
		}
	    }
	}
    }
}

/*
  Once we know the document is complete, select the first tab, make sure everything is sized correctly, and set up the refresh event.
*/
document.addEventListener("DOMContentLoaded", function(event) {
    selectTab("minecraft");
    resize();
    var evtSource = new EventSource("refresh.rb");
    evtSource.onmessage = updateStatus;
});

/*
  Make sure everything is sized correctly when there's a resize event
*/
window.onresize = function(event) {
    resize();
};
