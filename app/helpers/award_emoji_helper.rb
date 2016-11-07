module AwardEmojiHelper
  def toggle_award_url(awardable)
    return url_for([:toggle_award_emoji, awardable]) unless @project

    if awardable.is_a?(Note)
      # We render a list of notes very frequently and calling the specific method is a lot faster than the generic one (6.5x)
      toggle_award_emoji_namespace_project_note_url(namespace_id: @project.namespace, project_id: @project, id: awardable.id)
    else
      url_for([:toggle_award_emoji, @project.namespace.becomes(Namespace), @project, awardable])
    end
  end
end
