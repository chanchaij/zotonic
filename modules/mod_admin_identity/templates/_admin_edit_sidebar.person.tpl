<div class="item-wrapper" id="sort-user-credentials">
	<h3 class="above-item clearfix do_blockminifier { minifiedOnInit: true }">
		<span class="title">{_ Username / password _}</span>
		<span class="arrow">{_ make smaller _}</span>
	</h3>
	<div class="item clearfix admin-form">
		<div class="notification notice">
			{_ Add or remove credentials. _} <a href="javascript:void(0)" class="do_dialog {title: '{_ Help about user credentials. _}', text: '{_ When you add credentials to a person then the person becomes an user. A person or machine can log on with those credentials and perform actions on your Zotonic system.<br/><br/>What an user can do depends on the groups the user is member of. _}', width: '450px'}">Need more help?</a>
			
			<br />
			<strong>
			{% if m.identity[id].is_user %}
				{_ This person is also a user. _}
			{% else %}
				{_ This person is not yet a user. _}
			{% endif %}
			</strong>
		</div>

		{% if m.acl.is_allowed.use.mod_admin_identity or id == m.acl.user %}
			{% button action={dialog_set_username_password id=id} text=_"Set username / password" %}
		{% endif %}
		
		<div class="clear"></div>
		
		{% all include "_admin_edit_sidebar_identity.tpl" %}
	</div>
</div>
