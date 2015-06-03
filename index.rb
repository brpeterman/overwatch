#!/usr/bin/env ruby

require 'cgi'
require_relative 'server-status'

# Builds all HTML
# sections is a hash of server types to display
#  :servertype => "Display Name"
def build_html(sections)
  cgi = CGI.new('html5')
  status = ServerStatus.new(nil, true) # Don't send any queries yet. We'll do that asynchronously later

  # Build the tabs that show server status
  # Build the details section for each server
  tabs_html, sections_html = "", ""
  sections.each do |type, title|
    tabs_html += cgi.div({'id' => "#{type}-status",
                      'class' => 'statusline',
                      'onclick' => "selectTab('#{type}')"}) do
      title +
      cgi.span({'class' => 'status offline'}) do
        "Loading"
      end +
      ( status.respond_to?("#{type}_player_count") ?
        cgi.span({'class' => 'player-count'}) do
          "(...)"
        end
        : "" )
    end

    sections_html += send("build_#{type}_section", cgi, status)
  end

  # Output the HTML we just built
  cgi.out do
    cgi.html do
      "\n\n<!-- This HTML is auto-generated. Please don't judge me on the formatting. :) -->\n\n" +
      cgi.head do
        cgi.title { "Overwatch" } +
          cgi.link({'rel' => 'stylesheet',
                     'href' => 'style.css'}) +
          cgi.script({'type' => 'text/javascript',
                       'src' => 'script.js'}) +
          cgi.meta({'name' => 'viewport',
                     'content' => 'width=device-width, initial-scale=1'}) + # Let mobile devices do their own scaling
          cgi.meta({'charset' => 'utf-8'})
      end +
      cgi.body do
        cgi.div({'id' => 'status-box'}) do
          tabs_html
        end +
        sections_html
      end
    end
  end
end

# Not used right now
def build_general_section(cgi)
  
end

# Build HTML for Minecraft section
# cgi is the CGI object we're using for output
# status is the ServerStatus object
def build_minecraft_section(cgi, status)
  cgi.div({'id' => 'minecraft-section',
            'class' => 'section'}) do
    details_section(cgi, 'minecraft') do
      details_line(cgi, "Address", "mc.bpeterman.com:25765", 'address') +
      details_line(cgi, "MOTD", status.minecraft_motd, 'motd') +
      details_line(cgi, "Map",
                   cgi.a({'href' => 'http://mc.bpeterman.com:25766/'}) do
                     "http://mc.bpeterman.com:25766/"
                   end, 'map')
    end + 
    # Map IFrame
    cgi.div({'id' => 'map-container'}) do
      cgi.span({'id' => 'toggle-map',
                 'onclick' => 'toggleMap()'}) do
        "Show Map"
      end +
      cgi.iframe({'id' => 'map-frame', 'seamless' => 'seamless', 'src' => 'http://mc.bpeterman.com:25766'})
    end
  end
end

# Build HTML for Starbound section
# cgi is the CGI object we're using for output
# status is the ServerStatus object
def build_starbound_section(cgi, status)
  cgi.div({'id' => 'starbound-section',
            'class' => 'section'}) do
    details_section(cgi, 'starbound') do
      details_line(cgi, "Address", "overwatch.bpeterman.com", 'address')
    end
  end
end

# Build HTML for the Kerbal Space Program section
# cgi is the CGI object we're using for output
# status is the ServerStatus object
def build_kerbal_section(cgi, status)
  cgi.div({'id' => 'kerbal-section',
            'class' => 'section'}) do
    details_section(cgi, 'kerbal') do
      details_line(cgi, "Address", "overwatch.bpeterman.com", 'address') +
      details_line(cgi, "Players online", 
                   ( status.kerbal_player_list != "" ?
                     status.kerbal_player_list
                     : "None" ), 'player_list')
    end
  end
end

# Build HTML for the 7 Days to Die section
# cgi is the CGI object we're using for output
# status is the ServerStatus object
def build_sevendays_section(cgi, status)
  cgi.div({'id' => 'sevendays-section',
            'class' => 'section'}) do
    details_section(cgi, 'sevendays') do
      details_line(cgi, "Address", "overwatch.bpeterman.com:25000", 'address')
    end
  end
end

# Build HTML for the Mumble section
# cgi is the CGI object we're using for output
# status is the ServerStatus object
def build_mumble_section(cgi, status)
  cgi.div({'id' => 'mumble-section',
            'class' => 'section'}) do
    details_section(cgi, 'mumble') do
      details_line(cgi, "Address", "mumble.bpeterman.com:64857", 'address') +
      details_line(cgi, "Users online", 
                   ( status.mumble_player_list != "" ?
                     status.mumble_player_list
                     : "None" ), 'player_list')
    end
  end
end

# Build HTML for a line of the details section
# cgi is the CGI object we're using for output
# label is the label displayed for the line
# value is the value displayed for the line
# type is the type of field. Used in the CSS class.
def details_line(cgi, label, value, type)
  id = "#{type}-value"
  cgi.div({'class' => 'details-line'}) do
    cgi.span({'class' => 'details-label'}) do
      label
    end +
    cgi.span({'class' => "details-value #{id}"}) do
      value
    end
  end
end

# Build HTML for the server details section
# cgi is the CGI object we're using for output
# server_type is the type of server we're displaying (used in the element ID)
# block is a block that evaluates to the content of the section
def details_section(cgi, server_type, &block)
  cgi.div({'id' => (server_type + '-details'),
            'class' => 'details-section'}) do
    cgi.div({'class' => 'header'}) do
      "Server details"
    end +
    block.call
  end
end

# Establish which servers to show
sections = {}
sections[:minecraft] = "Minecraft"
sections[:starbound] = "Starbound"
#sections[:kerbal] = "Kerbal Space Program"
sections[:sevendays] = "7 Days to Die"
sections[:mumble] = "Mumble"

# Output the page
build_html(sections)
