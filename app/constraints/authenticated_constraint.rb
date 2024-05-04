class AuthenticatedConstraint
  def matches?(request)
    cookies = ActionDispatch::Cookies::CookieJar.build(request, request.cookies)
    session = Session.find_by_id(cookies.signed[Session::COOKIE_KEY])
    if session
      Current.session = session
      true
    else
      false
    end
  end
end
