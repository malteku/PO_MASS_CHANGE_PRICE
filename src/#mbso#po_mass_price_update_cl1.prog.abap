*&---------------------------------------------------------------------*
*& Include /MBSO/PO_MASS_PRICE_UPDATE_CL1
*& Klassenimplementierung: Datenselektion, ALV, BAPI-Verarbeitung
*&---------------------------------------------------------------------*

CLASS lcl_application IMPLEMENTATION.

*----------------------------------------------------------------------*
* Hauptablauf: Daten lesen, ALV anzeigen
*----------------------------------------------------------------------*
  METHOD run.
    select_data( ).

    IF po_items IS INITIAL.
      MESSAGE |Keine Bestellpositionen gefunden| TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    set_cell_styles( ).

    " Dieser Befehl wechselt offiziell in den Listen-Modus (Screen 120)
    LEAVE TO LIST-PROCESSING.

    display_alv( ).

    " Ein leeres WRITE sorgt dafür, dass der Screen 120 aktiv bleibt
    WRITE: space.
  ENDMETHOD.

*----------------------------------------------------------------------*
* Bestellpositionen aus EKKO/EKPO/LFA1 lesen
*----------------------------------------------------------------------*
  METHOD select_data.
    SELECT ekpo~ebeln,
           ekpo~ebelp,
           ekpo~matnr,
           ekpo~txz01,
           ekko~lifnr,
           lfa1~name1,
           ekpo~netpr,
           ekpo~peinh,
           ekpo~meins,
           ekko~waers
      FROM ekpo
      INNER JOIN ekko
        ON ekko~ebeln = ekpo~ebeln
      LEFT OUTER JOIN lfa1
        ON lfa1~lifnr = ekko~lifnr
      WHERE ekpo~ebeln IN @so_ebeln
        AND ekpo~ebelp IN @so_ebelp
        AND ekko~bedat IN @so_bedat
        AND ekko~lifnr IN @so_lifnr
        AND ekpo~loekz = @space
      INTO CORRESPONDING FIELDS OF TABLE @po_items.
  ENDMETHOD.

*----------------------------------------------------------------------*
* Zellstile setzen: NEW_PRICE als editierbar markieren
*----------------------------------------------------------------------*
  METHOD set_cell_styles.
    LOOP AT po_items ASSIGNING FIELD-SYMBOL(<item>).
      <item>-celltab = VALUE lvc_t_styl(
        ( fieldname = 'NEW_PRICE'
          style     = cl_gui_alv_grid=>mc_style_enabled )
      ).
    ENDLOOP.
  ENDMETHOD.

*----------------------------------------------------------------------*
* ALV-Grid mit Docking-Container erstellen und Daten anzeigen
*----------------------------------------------------------------------*
  METHOD display_alv.

    DATA: lo_alv TYPE REF TO cl_salv_table.



    " Falls schon ein Container existiert (bei mehrmaligem Aufruf), diesen löschen
*    IF container IS BOUND.
*      container->free( ).
*    ENDIF.
*
*    " Docking-Container erzeugen
*    container = NEW cl_gui_docking_container(
*      repid     = sy-repid
*      dynnr     = '0120' " WICHTIG: Erzwungene Bindung an das Listen-Dynpro
*      side      = cl_gui_docking_container=>dock_at_top
*      extension = 1000   " Nutze extension statt ratio für stabilere Anzeige
*    ).
*
*    " ALV-Grid erzeugen
*    alv_grid = NEW cl_gui_alv_grid(
*      i_parent = container
*    ).

    " Custom Container anstatt Docking Container
    DATA: lo_custom_container TYPE REF TO cl_gui_custom_container.

    " Hier referenzierst du den Namen, den du im Screen Painter vergeben hast (MY_CONTAINER)
    lo_custom_container = NEW cl_gui_custom_container(
      container_name = 'MY_CONTAINER'
    ).

    alv_grid = NEW cl_gui_alv_grid(
      i_parent = lo_custom_container
    ).
*
    " Event-Handler registrieren
    SET HANDLER on_toolbar     FOR alv_grid.
    SET HANDLER on_user_command FOR alv_grid.

    " Fieldcatalog und Layout vorbereiten
    DATA(fieldcatalog) = build_fieldcatalog( ).

    " ALV-Grid mit Daten befüllen
    alv_grid->set_table_for_first_display(
      EXPORTING
        is_layout       = build_layout( )
      CHANGING
        it_outtab       = po_items
        it_fieldcatalog = fieldcatalog
    ).

    " Editiermodus aktivieren
    alv_grid->register_edit_event(
      i_event_id = cl_gui_alv_grid=>mc_evt_modified
    ).

  ENDMETHOD.

*----------------------------------------------------------------------*
* Fieldcatalog aufbauen: Spalten und Editierbarkeit definieren
*----------------------------------------------------------------------*
  METHOD build_fieldcatalog.
    result = VALUE lvc_t_fcat(
      ( fieldname = 'EBELN'       coltext = 'Bestellung'       outputlen = 10 )
      ( fieldname = 'EBELP'       coltext = 'Position'          outputlen = 5  )
      ( fieldname = 'MATNR'       coltext = 'Material'          outputlen = 18 )
      ( fieldname = 'TXZ01'       coltext = 'Kurztext'          outputlen = 40 )
      ( fieldname = 'LIFNR'       coltext = 'Lieferant'         outputlen = 10 )
      ( fieldname = 'NAME1'       coltext = 'Lieferantenname'   outputlen = 35 )
      ( fieldname = 'NETPR'       coltext = 'Aktueller Preis'   outputlen = 13 )
      ( fieldname = 'PEINH'       coltext = 'Preiseinheit'      outputlen = 5  )
      ( fieldname = 'MEINS'       coltext = 'ME'                outputlen = 4  )
      ( fieldname = 'WAERS'       coltext = 'Währung'           outputlen = 5  )
      ( fieldname = 'NEW_PRICE'   coltext = 'Neuer Preis'       outputlen = 13  edit = abap_true )
      ( fieldname = 'STATUS_ICON' coltext = 'Status'            outputlen = 4   icon = abap_true )
      ( fieldname = 'MESSAGE'     coltext = 'Meldung'           outputlen = 60 )
    ).
  ENDMETHOD.

*----------------------------------------------------------------------*
* ALV-Layout konfigurieren
*----------------------------------------------------------------------*
  METHOD build_layout.
    result = VALUE lvc_s_layo(
      zebra      = abap_true
      cwidth_opt = abap_true
      stylefname = 'CELLTAB'
      sel_mode   = 'A'
    ).
  ENDMETHOD.

*----------------------------------------------------------------------*
* ALV-Toolbar: Custom-Button "Preise aktualisieren" hinzufügen
*----------------------------------------------------------------------*
  METHOD on_toolbar.
    " Separator einfügen
    APPEND VALUE stb_button(
      butn_type = 3
    ) TO e_object->mt_toolbar.

    " Button "Preise aktualisieren" hinzufügen
    APPEND VALUE stb_button(
      function  = 'UPDATE_PRICES'
      icon      = icon_change
      quickinfo = 'Markierte Preise aktualisieren'
      text      = 'Preise aktualisieren'
      disabled  = space
    ) TO e_object->mt_toolbar.
  ENDMETHOD.

*----------------------------------------------------------------------*
* ALV User-Command: Button-Klick verarbeiten
*----------------------------------------------------------------------*
  METHOD on_user_command.
    CASE e_ucomm.
      WHEN 'UPDATE_PRICES'.
        " Eingaben aus dem Frontend in die interne Tabelle übernehmen
        alv_grid->check_changed_data( ).

        " Preise per BAPI ändern
        update_prices( ).

        " ALV aktualisieren, um Protokoll (Status + Meldung) anzuzeigen
        alv_grid->refresh_table_display( ).
    ENDCASE.
  ENDMETHOD.

*----------------------------------------------------------------------*
* Preise per BAPI_PO_CHANGE aktualisieren (gruppiert nach Bestellung)
*----------------------------------------------------------------------*
  METHOD update_prices.
    " Prüfen ob Änderungen vorhanden sind
    DATA(changes_exist) = abap_false.
    LOOP AT po_items ASSIGNING FIELD-SYMBOL(<check>)
      WHERE new_price > 0.
      IF <check>-new_price <> <check>-netpr.
        changes_exist = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    IF changes_exist = abap_false.
      MESSAGE |Keine Preisänderungen vorhanden| TYPE 'S' DISPLAY LIKE 'W'.
      RETURN.
    ENDIF.

    " BAPI-Arbeitstabellen deklarieren
    DATA po_item_tab  TYPE ty_bapi_poitem.
    DATA po_itemx_tab TYPE ty_bapi_poitemx.
    DATA return_tab   TYPE ty_bapi_return.
    DATA has_error     TYPE abap_bool.
    DATA error_message TYPE bapi_msg.

    " Verarbeitung gruppiert nach Bestellnummer
    LOOP AT po_items ASSIGNING FIELD-SYMBOL(<item>)
      WHERE new_price > 0
      GROUP BY <item>-ebeln.

      " Tabellen für aktuelle Bestellung initialisieren
      CLEAR: po_item_tab, po_itemx_tab, return_tab,
             has_error, error_message.

      " BAPI-Eingabetabellen für diese Bestellung aufbauen
      LOOP AT GROUP <item> ASSIGNING FIELD-SYMBOL(<group_item>).
        " Nur Positionen mit tatsächlicher Preisänderung berücksichtigen
        IF <group_item>-new_price = <group_item>-netpr.
          CONTINUE.
        ENDIF.

        " Positionsdaten mit neuem Preis
        APPEND VALUE bapimepoitem(
          po_item   = <group_item>-ebelp
          net_price = <group_item>-new_price
        ) TO po_item_tab.

        " Änderungsflags: Position und Nettopreis ändern
        APPEND VALUE bapimepoitemx(
          po_item   = <group_item>-ebelp
          po_itemx  = 'X'
          net_price = 'X'
        ) TO po_itemx_tab.
      ENDLOOP.

      " Keine echten Änderungen in dieser Bestellung -> überspringen
      IF po_item_tab IS INITIAL.
        CONTINUE.
      ENDIF.

      " BAPI aufrufen
      CALL FUNCTION 'BAPI_PO_CHANGE'
        EXPORTING
          purchaseorder = <item>-ebeln
        TABLES
          poitem        = po_item_tab
          poitemx       = po_itemx_tab
          return        = return_tab.

      " Ergebnis auswerten: Fehler in RETURN suchen
      LOOP AT return_tab ASSIGNING FIELD-SYMBOL(<return>)
        WHERE type CA 'EA'.
        has_error = abap_true.
        IF error_message IS INITIAL.
          error_message = <return>-message.
        ENDIF.
      ENDLOOP.

      IF has_error = abap_false.
        " Erfolg: Änderung persistieren
        CALL FUNCTION 'BAPI_TRANSACTION_COMMIT'
          EXPORTING
            wait = abap_true.

        " Erfolgsstatus in ALV-Tabelle setzen
        LOOP AT po_items ASSIGNING FIELD-SYMBOL(<result>)
          WHERE ebeln     = <item>-ebeln
            AND new_price > 0.
          IF <result>-new_price <> <result>-netpr.
            <result>-status_icon = icon_green_light.
            <result>-message     = |Preis erfolgreich aktualisiert|.
            <result>-netpr       = <result>-new_price.
          ENDIF.
        ENDLOOP.
      ELSE.
        " Fehler: Transaktion zurückrollen
        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

        " Fehlerstatus in ALV-Tabelle setzen
        LOOP AT po_items ASSIGNING <result>
          WHERE ebeln     = <item>-ebeln
            AND new_price > 0.
          IF <result>-new_price <> <result>-netpr.
            <result>-status_icon = icon_red_light.
            <result>-message     = error_message.
          ENDIF.
        ENDLOOP.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
