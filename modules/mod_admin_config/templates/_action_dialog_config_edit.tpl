
<h3>{{ module|escape }}.{{ key|escape }}</h3>

{% wire id=#form type="submit" postback={config_edit module=module key=key on_success=on_success} delegate=delegate %}
<form id="{{ #form }}" method="POST" action="postback">
	<div class="new-predicate-wrapper">

		<div class="form-item clearfix">
			<label for="{{ #value }}">Value</label>
			<input type="text" id="{{ #value }}" name="val" value="{{ m.config[module][key].value|escape }}" />
		</div>

		<button type="submit">Save</button>
		{% button action={dialog_close} text="Cancel" %}
	</div>
</form>

