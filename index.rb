#!/usr/bin/env ruby

require 'cgi'
require_relative 'server-status'

def build_html(sections)
  cgi = CGI.new('html5')
  status = ServerStatus.new

  tabs_html, sections_html = "", ""
  sections.each do |type, title|
    tabs_html += cgi.div({'id' => "#{type}-status",
                      'class' => 'statusline',
                      'onclick' => "selectTab('#{type}')"}) do
      title + status.send("#{type}_status_text", cgi) +
        ( status.respond_to?("#{type}_player_count") ?
          cgi.span({'class' => 'player-count'}) do
            "(" + status.send("#{type}_player_count") + ")"
          end
          : "" )
    end

    sections_html += send("build_#{type}_section", cgi, status)
  end

  cgi.out do
    cgi.html do
      cgi.head do
        cgi.title { "Overwatch" } +
          cgi.link({'rel' => 'stylesheet',
                     'href' => 'style.css'}) +
          cgi.script({'type' => 'text/javascript',
                       'src' => 'script.js'}) +
          cgi.meta({'name' => 'viewport',
                     'content' => 'width=device-width, initial-scale=1'})
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

def build_general_section(cgi)
  
end

def build_minecraft_section(cgi, status)
  cgi.div({'id' => 'minecraft-section',
            'class' => 'section'}) do
    details_section(cgi, 'minecraft') do
      details_line(cgi, "Address", "mc.bpeterman.com:25765", 'address') +
      ( status.minecraft_status ?
        details_line(cgi, "MOTD", status.minecraft_motd, 'motd')
        : "" ) +
      details_line(cgi, "Map",
                   cgi.a({'href' => 'http://mc.bpeterman.com:25766/'}) do
                     "http://mc.bpeterman.com:25766/"
                   end, 'map')
    end + 
    cgi.div({'id' => 'map-container'}) do
      cgi.span({'id' => 'toggle-map',
                 'onclick' => 'toggleMap()'}) do
        "Show Map"
      end +
      cgi.iframe({'id' => 'map-frame', 'seamless' => 'seamless', 'src' => 'http://mc.bpeterman.com:25766'})
    end
  end
end

def build_starbound_section(cgi, status)
  cgi.div({'id' => 'starbound-section',
            'class' => 'section'}) do
    details_section(cgi, 'starbound') do
      details_line(cgi, "Address", "overwatch.bpeterman.com", 'address')
    end
  end
end

def build_kerbal_section(cgi, status)
  cgi.div({'id' => 'kerbal-section',
            'class' => 'section'}) do
    details_section(cgi, 'kerbal') do
      details_line(cgi, "Address", "overwatch.bpeterman.com", 'address') +
      ( status.kerbal_status ?
        details_line(cgi, "Players online", 
                     ( status.kerbal_player_list != "" ?
                       status.kerbal_player_list
                       : "None" ), 'player_list')
        : "" )
    end
  end
end

def build_sevendays_section(cgi, status)
  cgi.div({'id' => 'sevendays-section',
            'class' => 'section'}) do
    details_section(cgi, 'sevendays') do
      details_line(cgi, "Address", "overwatch.bpeterman.com:25000", 'address')
    end
  end
end

def build_mumble_section(cgi, status)
  cgi.div({'id' => 'mumble-section',
            'class' => 'section'}) do
    details_section(cgi, 'mumble') do
      details_line(cgi, "Address", "mumble.bpeterman.com:64857", 'address') +
      ( status.mumble_status ?
        details_line(cgi, "Users online", 
                     ( status.mumble_player_list != "" ?
                       status.mumble_player_list
                       : "None" ), 'player_list')
        : "" )
    end
  end
end

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

def details_section(cgi, server_type, &block)
  cgi.div({'id' => (server_type + '-details'),
            'class' => 'details-section'}) do
    cgi.div({'class' => 'header'}) do
      "Server details"
    end +
    block.call
  end
end

sections = {}
sections[:minecraft] = "Minecraft"
sections[:starbound] = "Starbound"
sections[:kerbal] = "Kerbal Space Program"
sections[:sevendays] = "7 Days to Die"
sections[:mumble] = "Mumble"

build_html(sections)
