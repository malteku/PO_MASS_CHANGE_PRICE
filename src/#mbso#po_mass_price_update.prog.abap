*&---------------------------------------------------------------------*
*& Report /MBSO/PO_MASS_PRICE_UPDATE
*& Massenänderung von Bestellpreisen (Nettopreis)
*&
*& Beschreibung:
*&   Liest Bestellpositionen aus EKKO/EKPO anhand Selektionskriterien,
*&   zeigt sie in einem editierbaren ALV-Grid an und aktualisiert die
*&   Nettopreise per BAPI_PO_CHANGE.
*&---------------------------------------------------------------------*
REPORT /mbso/po_mass_price_update.

INCLUDE /mbso/po_mass_price_update_top.
INCLUDE /mbso/po_mass_price_update_sel.
INCLUDE /mbso/po_mass_price_update_cl1.

*  NEW lcl_application( )->run( ).

DATA: go_app TYPE REF TO lcl_application.

START-OF-SELECTION.
  go_app = NEW lcl_application( ).
  go_app->run( ).

  " Anstatt LEAVE TO LIST-PROCESSING:
  CALL SCREEN 100.
