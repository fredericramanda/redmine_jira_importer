jQuery(document).ready(function($){
  var path = window.location.pathname;

  // On cible les pages de la liste des issues d'un projet
  if (!/\/projects\/[^\/]+\/issues(\/|$)/.test(path)) return;

  // Chemin souhaité : /projects/{project}/issues/import_jira
  var importPath = window.location.pathname + '/import_jira';

  // Recherche d'un lien vers la création d'une nouvelle issue
  var $newLink = $('a.new-issue, a.icon.icon-add').filter(function(){
    var txt = $(this).text().trim();
    // texte multilingue possible et fallback sur href
    var href = $(this).attr('href') || '';
    return /Nouvelle demande|New issue|Nouvelle tâche|Créer|New Issue/i.test(txt) || href.indexOf('/issues/new') !== -1;
  }).first();

  if ($newLink && $newLink.length) {
    // Prevent duplicate buttons
    if ($('#jira_importer_button').length) return;

    // Si le lien existe, construit le bouton qui ouvrira la modale
    var $btn = $('<a/>', {
      href: importPath,
      id: 'jira_importer_button',
      class: 'icon icon-import jira-import-button',
      text: 'Importer Jira'
    }).css({'margin-left':'8px'});

    // insert after the new issue button (keeps layout)
    $newLink.after($btn);

    // clic : empêcher navigation et charger la view new.html.erb dans une modale
    $btn.on('click', function(e){
      e.preventDefault();
      var url = $(this).attr('href');
      
      // Crée ou réutilise le conteneur modal
      var modalId = 'jira-import-modal';
      var $modal = $('#' + modalId);
      if (!$modal.length) {
        $modal = $('<div/>', {
          id: modalId,
          class: 'modal'
        }).appendTo('#ajax-modal');  // Utilise le conteneur modal de Redmine
      }

      // Charge et affiche le contenu
      $.get(url).done(function(html){
        $modal.html(html);
        showModal(modalId, '650px');
        setupFormHandlers($modal);
      });
    });
  }
});

function setupFormHandlers($modal) {
  var $form = $modal.find('#jira-import-form');
  if (!$form.length) return;

  var $progress = $modal.find('#import-progress');
  var $results = $modal.find('#import-results');
  var $submitBtn = $modal.find('#import-submit');
  var $cancelBtn = $modal.find('#cancel-import');
  var $textArea = $form.find('textarea[name="jira_urls"]');

  $form.off('submit').on('submit', function(e) {
    e.preventDefault();
    e.stopImmediatePropagation();

    // Show progress and disable submit button
    $progress.show();
    $results.hide().empty(); // Hide and clear previous results
    $submitBtn.prop('disabled', true).val('Importing...');

    $.ajax({
      url: $form.attr('action'),
      type: 'POST',
      data: $form.serialize(),
      dataType: 'json',
      success: function(data) {
        var successHtml = '';
        if (data.success && data.success.length > 0) {
          successHtml += '<h4>✅ Successfully Imported</h4><ul>';
          data.success.forEach(function(item) {
            const currentPath = window.location.pathname;
            const url = currentPath.replace(/\/projects\/[^/]+\/issues.*$/, '/issues/');
            successHtml += '<li><a href="' + url + item.issue_id + '">' + item.issue_subject + '</a> (from ' + item.url + ')</li>';
          });
          successHtml += '</ul>';
        }

        var errorHtml = '';
        if (data.errors && data.errors.length > 0) {
          errorHtml += '<h4>❌ Failed Imports</h4><ul>';
          data.errors.forEach(function(item) {
            errorHtml += '<li>' + item.url + ' - <strong>Error:</strong> ' + item.error + '</li>';
          });
          errorHtml += '</ul>';
        }
        
        $results.html(successHtml + errorHtml).show();
      },
      error: function(xhr, status, err) {
        var errorMsg = 'An unexpected error occurred. Please check the server logs.';
        if (xhr.responseText) {
          try {
            var response = JSON.parse(xhr.responseText);
            errorMsg = response.error || errorMsg;
          } catch (e) { /* Ignore parsing error */ }
        }
        $results.html('<div class="flash error"><h4>Request Failed</h4><p>' + errorMsg + '</p></div>').show();
      },
      complete: function() {
        // Hide progress and re-enable submit button
        $progress.hide();
        $submitBtn.prop('disabled', false).val('Import');
        $cancelBtn.text('Close');
        $textArea.data('changed', false);
      }
    });
  });

  $cancelBtn.off('click').on('click', function() {
    const form = $('#jira-import-form');
    form[0].reset(); // Reset form fields to their default values
    $(this).closest('.modal').dialog('close');
  });

  // Optional: Reset form when closing the modal to prevent lingering unsaved changes
  $('.ui-dialog-titlebar-close').off('click').on('click', function () {
    const form = $('#jira-import-form');
    form[0].reset(); // Reset form fields to their default values
    $(this).closest('.modal').dialog('close');
  });
}
