/*
  Displays the section corresponding to the tab the user clicked on and hides whatever was active before.
  Also refreshes the data displayed in the section.
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

    // Get the latest info for this tab
    var xmlhttp = new XMLHttpRequest();
    xmlhttp.open("GET", "refresh.rb?server=" + tab, true);
    xmlhttp.onreadystatechange = (function(xmlobj, id) {
	return function() { updateStatus(xmlobj, id); } })(xmlhttp, tab);
    xmlhttp.send();
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
  XMLHHTPRequest handler.
  Updates the status of whatever servers it knows about with the latest information.
*/
function updateStatus(xmlhttp, tab) {
    if (xmlhttp.readyState == 4 && xmlhttp.status == 200) {
	var status = JSON.parse(xmlhttp.responseText);
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
	}
	if (tab != "") {
	    var serverStatus = status[tab];
	    var sectionElem = document.getElementById(tab + "-section");
	    if (sectionElem) {
		for (var key in serverStatus) {
		    var selector = "." + key.replace(' ', '_') + "-value";
		    var valueElem = sectionElem.querySelector(selector);
		    if (valueElem) {
			if (key == "player list" && serverStatus[key] == "") {
			    serverStatus[key] = "None";
			}
			valueElem.innerHTML = serverStatus[key];
		    }
		}
	    }
	}
    }
}

/*
  Sends AJAX requests to update both the status tabs and the currently displayed section.
*/
function refreshAll() {
    var xmlhttp = new XMLHttpRequest();
    xmlhttp.open("GET", "refresh.rb", true);
    xmlhttp.onreadystatechange = (function(xmlobj, id) {
	return function() { updateStatus(xmlobj, id); } })(xmlhttp, "");
    xmlhttp.send();
    // Also refresh the details of the currently-selected tab
    var selectedElem = document.querySelector(".statusline.selected");
    if (selectedElem) {
	var selected = selectedElem.id.split("-")[0];
	xmlhttp = new XMLHttpRequest();
	xmlhttp.open("GET", "refresh.rb?server=" + selected, true);
	xmlhttp.onreadystatechange = (function(xmlobj, id) {
	    return function() { updateStatus(xmlobj, id); } })(xmlhttp, selected);
	xmlhttp.send();
    }
}

/*
  Once we know the document is complete, select the first tab, make sure everything is sized correctly, and set up the refresh timer.
*/
document.addEventListener("DOMContentLoaded", function(event) {
    selectTab("minecraft");
    resize();
    window.setInterval(function() { refreshAll(); }, 1000);
});

/*
  Make sure everything is sized correctly when there's a resize event
*/
window.onresize = function(event) {
    resize();
};
