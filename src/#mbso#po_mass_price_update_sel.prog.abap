*&---------------------------------------------------------------------*
*& Include /MBSO/PO_MASS_PRICE_UPDATE_SEL
*& Selektionsbild: SELECT-OPTIONS für Bestelldaten
*&---------------------------------------------------------------------*

" Textelement TEXT-b01 = 'Selektionskriterien'
SELECTION-SCREEN BEGIN OF BLOCK selection WITH FRAME TITLE TEXT-b01.
  SELECT-OPTIONS:
    so_ebeln FOR purchase_order,    " Bestellnummer
    so_ebelp FOR po_item_number,    " Positionsnummer
    so_bedat FOR document_date,     " Belegdatum
    so_lifnr FOR vendor.            " Lieferant
SELECTION-SCREEN END OF BLOCK selection.
