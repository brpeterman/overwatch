#!/usr/bin/env ruby

require 'cgi'
require_relative 'server-status'

##
# Outputs HTML to display the status page
# [sections] Hash of sections to display:
#            :servertype => "Display Name"
def output_html(sections)
  cgi = CGI.new('html5')
  status = Overwatch::ServerStatus.new(skip_query: true) # Don't send any queries yet. We'll do that asynchronously later

  cgi.out do
    CGI::pretty(build_html(cgi, status, sections))
  end
end

##
# Returns the HTML needed to display the status page.
# [cgi] CGI object used for output
# [status] ServerStatus object.
# [sections] Hash of sections to display:
#            :servertype => "Display Name"
def build_html(cgi, status, sections)
  cgi.html do
    build_head_html(cgi) +
    build_body_html(cgi, status, sections)
  end
end

##
# Returns the HTML for the HEAD section.
# [cgi] CGI object used for output.
def build_head_html(cgi)
  cgi.head do
    cgi.title { "Overwatch" } +
    cgi.link('rel' => 'stylesheet',
             'href' => 'style.css') +
    cgi.script('type' => 'text/javascript',
               'src' => 'script.js') +
    cgi.meta('name' => 'viewport',
             'content' => 'width=device-width, initial-scale=1') + # Let mobile devices do their own scaling
    cgi.meta('charset' => 'utf-8')
  end
end

##
# Returns the HTML for the BODY section.
# [cgi] CGI object used for output.
# [status] ServerStatus object
# [sections] Hash of sections to display.
def build_body_html(cgi, status, sections)
  cgi.body do
    cgi.div('id' => 'main-container') do
      cgi.div('id' => 'tabs') do
        cgi.div('id' => 'status-box') do
          build_tabs_html(cgi, status, sections)
        end +
        cgi.div('id' => 'show-hide-tabs') do
          "Hide tabs"
        end
      end +
      cgi.div('id' => 'sections') do
        build_sections_html(cgi, status, sections)
      end
    end
  end
end

##
# Returns HTML for the tabs that display individual server statuses.
# [cgi] CGI object used for output.
# [status] ServerStatus object
# [sections] Hash of sections to display.
def build_tabs_html(cgi, status, sections)
  sections.reduce("") do |html, (type, title)|
    html += cgi.div('id' => "#{type}-status",
                    'class' => 'statusline',
                    'onclick' => "selectTab('#{type}')") do
      cgi.div('class' => 'status-title') do
        title +
          if status.respond_to?("#{type}_player_count")
            cgi.span('class' => 'player-count') do
            "(...)"
          end
          else
            ""
          end
      end +
        cgi.div('class' => 'status-summary') do
        cgi.span('class' => 'status offline') do
          "Loading"
        end
      end
    end
  end
end

##
# Returns HTML for the details sections of the servers.
# [cgi] CGI object used for output.
# [status] ServerStatus object
# [sections] Hash of sections to display.
def build_sections_html(cgi, status, sections)
  sections.keys.reduce("") do |html, type|
    html += send("build_#{type}_section", cgi, status)
  end
end

# Not used right now
def build_general_section(cgi)
  
end

##
# Build HTML for Minecraft section
# [cgi] CGI object used for output.
# [status] ServerStatus object
def build_minecraft_section(cgi, status)
  cgi.div('id' => 'minecraft-section',
          'class' => 'section') do
    details_section(cgi, 'minecraft') do
      details_line(cgi, "Address", status.minecraft_address, 'address') +
      details_line(cgi, "MOTD", status.minecraft_motd, 'motd') +
      details_line(cgi, "Map",
                   cgi.a('href' => 'http://mc.bpeterman.com:25766/') do
                     "http://mc.bpeterman.com:25766/"
                   end, 'map')
    end + 
    # Map IFrame
    cgi.div('id' => 'map-container') do
      cgi.span('id' => 'toggle-map',
               'onclick' => 'toggleMap()') do
        "Show Map"
      end +
      cgi.iframe('id' => 'map-frame',
                 'seamless' => 'seamless',
                 'src' => 'http://mc.bpeterman.com:25766')
    end
  end
end

##
# Build HTML for Starbound section
# [cgi] CGI object used for output.
# [status] ServerStatus object
def build_starbound_section(cgi, status)
  cgi.div('id' => 'starbound-section',
          'class' => 'section') do
    details_section(cgi, 'starbound') do
      details_line(cgi, "Address", status.starbound_address, 'address')
    end
  end
end

##
# Build HTML for the Kerbal Space Program section
# [cgi] CGI object used for output.
# [status] ServerStatus object
def build_kerbal_section(cgi, status)
  cgi.div('id' => 'kerbal-section',
          'class' => 'section') do
    details_section(cgi, 'kerbal') do
      details_line(cgi, "Address", status.kerbal_address, 'address') +
      details_line(cgi, "Players online", 
                   if status.kerbal_player_list
                     status.kerbal_player_list.join(', ')
                   else
                     "None"
                   end, 'player_list')
    end
  end
end

##
# Build HTML for the 7 Days to Die section
# [cgi] CGI object used for output.
# [status] ServerStatus object
def build_sevendays_section(cgi, status)
  cgi.div('id' => 'sevendays-section',
          'class' => 'section') do
    details_section(cgi, 'sevendays') do
      details_line(cgi, "Address", status.sevendays_address, 'address')
    end
  end
end

##
# Build HTML for the Mumble section
# [cgi] CGI object used for output.
# [status] ServerStatus object
def build_mumble_section(cgi, status)
  cgi.div('id' => 'mumble-section',
          'class' => 'section') do
    details_section(cgi, 'mumble') do
      details_line(cgi, "Address", status.mumble_address, 'address') +
      details_line(cgi, "Users online", 
                   if status.mumble_player_list
                     status.mumble_player_list.join(', ')
                   else
                     "None"
                   end, 'player_list')
    end
  end
end

##
# Build HTML for the Terraria section
# [cgi] CGI object used for output.
# [status] ServerStatus object
def build_terraria_section(cgi, status)
  cgi.div('id' => 'terraria-section',
          'class' => 'section') do
    details_section(cgi, 'terraria') do
      details_line(cgi, "Address", status.terraria_address, 'address') +
      details_line(cgi, "Users online", 
                   if status.terraria_player_list
                     status.terraria_player_list.join(', ')
                   else
                     "None"
                   end, 'player_list')
    end
  end
end

##
# Build HTML for a line of the details section
# [cgi] CGI object used for output.
# [label] the label displayed for the line
# [value] the value displayed for the line
# [type] the type of field. Used in the CSS class.
def details_line(cgi, label, value, type)
  id = "#{type}-value"
  cgi.div('class' => 'details-line') do
    cgi.span('class' => 'details-label') do
      label
    end +
    cgi.span('class' => "details-value #{id}") do
      value
    end
  end
end

##
# Build HTML for the server details section
# [cgi] CGI object used for output.
# [server_type] the type of server we're displaying (used in the element ID)
# [block] block that evaluates to the content of the section
def details_section(cgi, server_type, &block)
  cgi.div('id' => (server_type + '-details'),
          'class' => 'details-section') do
    cgi.div('class' => 'header') do
      "Server details"
    end +
    block.call
  end
end

# Establish which servers to show
sections = {}
sections[:minecraft] = "Minecraft"
sections[:terraria] = "Terraria"
sections[:starbound] = "Starbound"
sections[:kerbal] = "Kerbal Space Program"
sections[:sevendays] = "7 Days to Die"
sections[:mumble] = "Mumble"

# Output the page
output_html(sections)
