*&---------------------------------------------------------------------*
*& Include /MBSO/PO_MASS_PRICE_UPDATE_TOP
*& Globale Definitionen: Typen, Referenzvariablen, Klassendefinitionen
*&---------------------------------------------------------------------*

*----------------------------------------------------------------------*
* Typdefinitionen
*----------------------------------------------------------------------*
TYPES:
  BEGIN OF ty_po_item,
    ebeln       TYPE ekpo-ebeln,       " Bestellnummer
    ebelp       TYPE ekpo-ebelp,       " Positionsnummer
    matnr       TYPE ekpo-matnr,       " Materialnummer
    txz01       TYPE ekpo-txz01,       " Kurztext Material
    lifnr       TYPE ekko-lifnr,       " Lieferant
    name1       TYPE lfa1-name1,       " Lieferantenname
    netpr       TYPE ekpo-netpr,       " Aktueller Nettopreis
    peinh       TYPE ekpo-peinh,       " Preiseinheit
    meins       TYPE ekpo-meins,       " Mengeneinheit
    waers       TYPE ekko-waers,       " Währung
    new_price   TYPE ekpo-netpr,       " Neuer Preis (editierbar im ALV)
    celltab     TYPE lvc_t_styl,       " Zellstil für Editierbarkeit
    status_icon TYPE icon-id,          " Ampel-Icon (Erfolg/Fehler)
    message     TYPE bapi_msg,         " BAPI-Rückmeldung
  END OF ty_po_item,

  ty_po_items TYPE STANDARD TABLE OF ty_po_item WITH DEFAULT KEY,

  " BAPI-Tabellentypen für BAPI_PO_CHANGE
  ty_bapi_poitem  TYPE STANDARD TABLE OF bapimepoitem  WITH DEFAULT KEY,
  ty_bapi_poitemx TYPE STANDARD TABLE OF bapimepoitemx WITH DEFAULT KEY,
  ty_bapi_return  TYPE STANDARD TABLE OF bapiret2      WITH DEFAULT KEY.

*----------------------------------------------------------------------*
* Referenzvariablen für SELECT-OPTIONS (statt obsoletes TABLES)
*----------------------------------------------------------------------*
DATA: purchase_order TYPE ekko-ebeln,
      po_item_number TYPE ekpo-ebelp,
      document_date  TYPE ekko-bedat,
      vendor         TYPE ekko-lifnr.

*----------------------------------------------------------------------*
* Klassendefinition: lcl_application
*----------------------------------------------------------------------*
CLASS lcl_application DEFINITION FINAL.

  PUBLIC SECTION.
    METHODS run.

  PRIVATE SECTION.
    DATA po_items  TYPE ty_po_items.
    DATA alv_grid  TYPE REF TO cl_gui_alv_grid.
    DATA container TYPE REF TO cl_gui_docking_container.

    " Datenselektion
    METHODS select_data.

    " ALV-Anzeige
    METHODS display_alv.

    METHODS build_fieldcatalog
      RETURNING VALUE(result) TYPE lvc_t_fcat.

    METHODS build_layout
      RETURNING VALUE(result) TYPE lvc_s_layo.

    METHODS set_cell_styles.

    " Preisänderung via BAPI
    METHODS update_prices.

    " ALV Event-Handler
    METHODS on_toolbar
      FOR EVENT toolbar OF cl_gui_alv_grid
      IMPORTING e_object e_interactive.

    METHODS on_user_command
      FOR EVENT user_command OF cl_gui_alv_grid
      IMPORTING e_ucomm.

ENDCLASS.
