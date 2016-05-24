xml.instruct!
xml.feed "xmlns" => "http://www.w3.org/2005/Atom", "xmlns:media" => "http://search.yahoo.com/mrss/" do
  xml.title   "Activity"
  xml.link    href: dashboard_projects_url(format: :atom, private_token: current_user.try(:private_token)), rel: "self", type: "application/atom+xml"
  xml.link    href: dashboard_projects_url, rel: "alternate", type: "text/html"
  xml.id      dashboard_projects_url
  xml.updated @events[0].updated_at.xmlschema if @events[0]

  @events.each do |event|
    event_to_atom(xml, event)
  end
end
