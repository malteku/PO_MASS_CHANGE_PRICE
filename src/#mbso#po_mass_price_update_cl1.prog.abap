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
    display_alv( ).

    " Listausgabe erzwingen, damit der Docking-Container sichtbar wird
    WRITE space.
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
    " Docking-Container erzeugen (kein Dynpro nötig)
    container = NEW cl_gui_docking_container(
      ratio = 95
      side  = cl_gui_docking_container=>dock_at_top
    ).

    " ALV-Grid erzeugen
    alv_grid = NEW cl_gui_alv_grid(
      i_parent = container
    ).

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
    LOOP AT po_items TRANSPORTING NO FIELDS
      WHERE new_price > 0
        AND new_price <> netpr.
      changes_exist = abap_true.
      EXIT.
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
        AND new_price <> netpr
      GROUP BY <item>-ebeln.

      " Tabellen für aktuelle Bestellung initialisieren
      CLEAR: po_item_tab, po_itemx_tab, return_tab,
             has_error, error_message.

      " BAPI-Eingabetabellen für diese Bestellung aufbauen
      LOOP AT GROUP <item> ASSIGNING FIELD-SYMBOL(<group_item>).
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
            AND new_price > 0
            AND new_price <> netpr.
          <result>-status_icon = icon_green_light.
          <result>-message     = |Preis erfolgreich aktualisiert|.
          <result>-netpr       = <result>-new_price.
        ENDLOOP.
      ELSE.
        " Fehler: Transaktion zurückrollen
        CALL FUNCTION 'BAPI_TRANSACTION_ROLLBACK'.

        " Fehlerstatus in ALV-Tabelle setzen
        LOOP AT po_items ASSIGNING <result>
          WHERE ebeln     = <item>-ebeln
            AND new_price > 0
            AND new_price <> netpr.
          <result>-status_icon = icon_red_light.
          <result>-message     = error_message.
        ENDLOOP.
      ENDIF.

    ENDLOOP.
  ENDMETHOD.

ENDCLASS.
