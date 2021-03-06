{% with m.rsc[id] as r %}
<div class="item-wrapper">
    <h3 class="above-item clearfix do_blockminifier { minifiedOnInit: false }">
        <span class="title">{_ Body text _}</span>
        <span class="arrow">{_ make smaller _}</span>
    </h3>
    <div class="item">
        <fieldset class="admin-form">
            {% button action={zmedia id=id media_div_id=#media subject_id=id} text=_"Add media to body" id="zmedia-open-dialog" style="display:none" %}
            {% wire action={event type='named' name="zmedia" action={zmedia id=id media_div_id=#media subject_id=id}} %}
            {% wire action={event type='named' name="zlink" action={dialog_open title="Add link" template="_action_dialog_zlink.tpl"}} %}

            <div class="form-item clearfix">
                {% if is_editable %}
                <textarea rows="10" cols="10" id="rsc-body" name="body" class="body tinymce">{{ r.body|escape }}</textarea>
                {% else %}
                {{ r.body }}
                {% endif %}
            </div>

            {% include "_admin_save_buttons.tpl" %}

        </fieldset>
    </div>
</div>
{% endwith %}
