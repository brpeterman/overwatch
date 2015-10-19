# Place public functions in document.Overwatch namespace
document.Overwatch =
  ###
  #  Displays the section corresponding to the tab the user clicked on and hides
  #  whatever was active before.
  ###
  selectTab: (tabName) ->
    tabs = document.getElementsByClassName("statusline")
    tab.classList.remove("selected") for tab in tabs
    
    activeTab = document.getElementById("#{tabName}-status")
    activeTab.classList.add("selected")
    
    sections = document.getElementsByClassName("section")
    section.classList.remove("selected") for section in sections
    
    activeSection = document.getElementById("#{tabName}-section")
    activeSection.classList.add("selected")

  ###
  #  Show/hide the Minecraft map
  ###
  toggleMap: ->
    mapElem = document.getElementById("map-frame")
    linkElem = document.getElementById("toggle-map")
    if mapElem.style.display == "block"
      mapElem.style.display = "none"
      linkElem.innerHTML = "Show Map"
    else
      mapElem.style.display = "block"
      linkElem.innerHTML = "Hide Map"

  ###
  #  Make sure everything is the right size
  ###
  resize: ->
    sections = document.getElementsByClassName("section")
    rect = sections[0].getBoundingClientRect()
    browserHeight = document.documentElement.clientHeight
    section.style.height = "#{(browserHeight - rect.top - 15)}px" for section in sections

  ###
  #  EventSource message handler
  #  Updates the status of whatever servers it knows about with the latest information.
  ###
  updateStatus: (e) ->
    return if !e.data?
    status = JSON.parse(e.data)
    for key of status
      tabElem = document.getElementById("#{key}-status")
      if tabElem?
        statusElem = tabElem.querySelector(".status")
        if status[key]["status"]
          statusElem.classList.remove("offline")
          statusElem.classList.add("online")
          statusElem.innerHTML = "Online"
        else
          statusElem.classList.remove("online")
          statusElem.classList.add("offline")
          statusElem.innerHTML = "Offline"
      countElem = tabElem.querySelector(".player-count")
      if countElem?
        countElem.innerHTML = "(#{status[key]['player_count']})"
      serverStatus = status[key]
      sectionElem = document.getElementById("#{key}-section")
      if sectionElem?
        for field of serverStatus
          selector = ".#{field.replace(' ', '_')}-value"
          valueElem = sectionElem.querySelector(selector)
          if valueElem?
            if field == "player_list"
              if serverStatus[field] == ""
                serverStatus[field] = "None"
              else
                serverStatus[field] = serverStatus[field].join(', ')
            else if field == "motd"
              serverStatus[field] = URI.withinString serverStatus[field], (url) ->
                return "<a href=\"#{url}\">#{url}</a>"
            else if field == "last_actvity"
              if serverStatus[field] == null
                serverStatus[field] = "Unknown"
              else
                date = Date.new(serverStatus[field]*1000)
                serverStatus[field] = date.toString()
            valueElem.innerHTML = serverStatus[field]

###
#  Once we know the document is complete, select the first tab,
#  make sure everything is sized correctly, and set up the refresh event.
###
document.addEventListener "DOMContentLoaded", (event) ->
  if document.location.hash != ""
    selection = document.location.hash.substring(1)
    document.Overwatch.selectTab(selection)
  else
    document.Overwatch.selectTab("minecraft")
  
  document.Overwatch.resize()
  evtSource = new EventSource("refresh.rb")
  evtSource.onmessage = document.Overwatch.updateStatus

###
#  Make sure everything is sized correctly when there's a resize event
###
window.onresize = (event) ->
  document.Overwatch.resize()
