if (Trio == undefined) var Trio = {};

//Manager Constructor
Trio.ReportWizard = function () {
  var that = this;

  this._generating = false;

  $.ajaxSetup( { async: false } );

  $('#report_wizard_dialog').dialog( { modal : true, autoOpen: false, closeOnEscape: false,  dialogClass: 'no-close' } );

  $('body').append('\
    <div id="dialog-form" title="Detalhes" style="display:none;">\
      <br>\
      <div class="ui-widget" style="width:100%,height:100%" id="dialog-form-content">\
      </div>\
    </div>\
  ');

  $(document).on('change', '#pred_value', function() {
    var val = $('#pred_value').val();

    $.ajax({
      url : '/wbo/common/api.pl',
      global: false,
      type: "POST",
      dataType: "json",
      data: { 'op' : 'save_pred_value', 'pred_value' : val },
      traditional : true,
      async: true,
      success: function(json){
        $('#last_user').html( json.user );
      }
   });
  });

  $(document).on('click','#manageTemplates', function() {
    populateTemplates();

    $("#template_save").dialog({
      modal: true,
      width: 400,
      buttons:  {
        'Gravar' : function() {
          var data = {};

          var items = $('.ReportWizardDimensionData, .ReportWizardGroup, .ReportWizardDatatypes');
          for (var i = 0; i < items.length; i++) {
            var item = $( items[i] );

            if (typeof item.data('notmpl') == "undefined") {
              if ( item.is(':checkbox') ) {
                data[ item.attr('name') ] = item.is(':checked') ? 1 : 0;
              } else {
                data[ item.attr('name') ] = item.val();
              }
            }
          }

          $.ajax({
            url : '/wbo/common/api.pl',
            global: false,
            type: "POST",
            dataType: "html",
            data: $("#report_wizard_form").serialize(),
            traditional : true,
            async: true,
            success: function(html){
            }
          });
        },
        'Fechar' : function() {
          $( this ).dialog( "close" );
        }
      }
    });
  });

  $(document).on('click','.generateReport', function() {
    $('#format').val( $(this).val() );

    if ( $(this).val() == 'xls') {
      if ( ! that._generating ) {
        $('#report_wizard_dialog').dialog("open");

        $.ajax({
          global: false,
          type: "POST",
          dataType: "html",
          data: $("#report_wizard_form").serialize(),
          traditional : true,
          async: true,
          beforeSend : function() {
            that._generating = true;
          },
          success: function(html){
            $('#report_wizard_dialog').dialog("close");
            that._generating = false;
            location.href='/woff/'+html;
          }
        });
      }
    } else { 
      if ( ! that._generating ) {
        $('#report_wizard_dialog').dialog("open");

        $.ajax({
          global: false,
          type: "POST",
          dataType: "html",
          data: $("#report_wizard_form").serialize(),
          traditional : true,
          async: true,
          beforeSend : function() {
            $("#content").hide();
            that._generating = true;
          },
          success: function(html){
            $("#content").html(html);
            $("#content").show();

/*
            $('#report_table').dataTable( {
              "sScrollX" : "100%",
              "sScrollY": "60%",
              "bPaginate": false,
              "bFilter": false,
              "bSort" : false,
            } );

*/

            $('#report_wizard_dialog').dialog("close");
       
            that._generating = false; 
          },
          error : function(html) {
            $('#report_wizard_dialog').dialog("close");

            that._generating = false;
            alert('Aconteceu um erro por favor tente de novo');
          }
        });
      } else {

      }
    }
  });

  $(document).on('change', '.ReportWizardDimensionData', function(event) {
    if (event.stop) {
      return false;
    } else {
      that.reloadDimensionData();
      return false;
    }
  });

  $(document).on('mouseover','.rw_mover',function() { 
    this.style.cursor = 'pointer';
    that.showToolTip( $(this).attr('mover_data'),this );
  });

  $(document).on('mouseout', '.rw_mover', function() {
    that.hideToolTip();
  });

  $(document).on('mouseover','.rw_click', function() {
    this.style.cursor = 'pointer';
  });

  $(document).on('click', '.rw_click', function() {
    if (that._modal) {
    } else {
      $("#dialog-form").dialog({
        autoOpen: false,
        height: 300,
        width: 800,
        modal: true,
        buttons:  {
        } 
      });
    }

    $.ajax({
      type: "GET",
      url: $(this).data('href'),
      dataType: "html",
      async: true,
      global: false,
      success: function(html) {
        $('#dialog-form-content').html('');
        $('#dialog-form').dialog('open');
        $('#dialog-form-content').html(html);
      }
    });
  });

  $(document).on('mouseover', '.rw_sortup', function() {
   this.style.cursor = 'pointer';
  });

  $(document).on('mouseover', '.rw_sortdown', function() {
   this.style.cursor = 'pointer';
  });

  $(document).on('click', '.rw_sortup', function() {
    $('#sort_field').val( $(this).attr('sort_dt') );
    $('#sort_key').val( $(this).attr('sort_key') );
    $('#sort_direction').val('up');

    $('#generateHTML').click();
  });

  $(document).on('click', '.rw_sortdown', function() {
    $('#sort_field').val( $(this).attr('sort_dt') );
    $('#sort_key').val( $(this).attr('sort_key') );
    $('#sort_direction').val('down');

    $('#generateHTML').click();
  });
  //INIT DATEA
}

Trio.ReportWizard.prototype = {
  hideToolTip : function () { $('#rw_tooltip').hide(); },
  showToolTip : function( html, element ) {
    var $rw_tooltip = $('#rw_tooltip');
    var $element = $(element);

    var position = $element.position();

    $rw_tooltip.css('left', position.left+'px');
    $rw_tooltip.css('top', position.top+$element.outerHeight() );

    $rw_tooltip.html(html);
    $rw_tooltip.show();
  },
  reloadDimensionData: function() {
    var that = this;

    $('#format').val('json');
    $('#generate').val(0);

    $.ajax({
       type: "POST",
       url: "/wbo/app",
       data: $("#report_wizard_form").serialize(),
       dataType: "json",
       async: false,
       global: false,
       beforeSend: function() {
         $('#report_wizard_dialog').dialog("open");
       },
       success: function(json) {
         for (var selector in json) {
           var domId = json[selector]['id'];
           var $domEl = $('#'+json[selector]['id']);
           var domData = json[selector]['data'];
           var len = domData.length;

           var str = '';
           for (var i = 0; i < len; i++) {
             str += '<option value="';
             str += domData[i]['id'];
             str += '"';
             str += ( domData[i]['selected'] == 1 ? ' selected' : '' )
             str += '>';
             str += domData[i]['name'];
             str += '</option>';
           }

           $domEl.html(str);
           $domEl.trigger( { type : 'change', stop : true } );

           $('#report_wizard_dialog').dialog("close");
           $('#format').val('html');
           $('#generate').val(1);
         }
       },
       error: function(json) {
         $('#report_wizard_dialog').dialog("close");
         $('#generate').val(1);
         $('#format').val('html');
       }
    });
  }
};

