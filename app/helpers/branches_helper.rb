module BranchesHelper
  def can_remove_branch?(project, branch_name)
    if project.protected_branch? branch_name
      false
    elsif branch_name == project.repository.root_ref
      false
    elsif !current_user.is_admin? #CUSTOM - only admins can remove branches
      false
    else
      can?(current_user, :push_code, project)
    end
  end

  def can_push_branch?(project, branch_name)
    return false unless project.repository.branch_exists?(branch_name)

    ::Gitlab::GitAccess.new(current_user, project, 'web').can_push_to_branch?(branch_name)
  end

  def project_branches
    options_for_select(@project.repository.branch_names, @project.default_branch)
  end
end
