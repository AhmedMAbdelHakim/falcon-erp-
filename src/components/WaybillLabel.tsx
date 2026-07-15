import React from 'react';
import { Barcode, QRCodeComponent } from './BarcodeQR';

interface WaybillLabelProps {
  label: {
    tracking_number: string;
    customer_name: string;
    primary_phone: string;
    secondary_phone?: string;
    governorate: string;
    city: string;
    address: string;
    landmark?: string;
    contents: string;
    pieces: number;
    weight: number;
    cod_amount: number;
    shipping_fee: number;
    payment_method: string;
    instructions?: string;
    shipper_id: string;
    store_name: string;
    product_type: string;
    created_at: string;
  };
  layout?: '2' | '3'; // '2' = 2 labels per A4 page, '3' = 3 labels per A4 page
}

export const WaybillLabel: React.FC<WaybillLabelProps> = ({ label, layout = '3' }) => {
  const isLayout3 = layout === '3';
  
  // Outer label dimensions
  const labelStyle: React.CSSProperties = {
    width: '190mm',
    height: isLayout3 ? '86mm' : '128mm',
    boxSizing: 'border-box',
    border: '1.5px solid #000000',
    backgroundColor: '#FFFFFF',
    color: '#000000',
    display: 'flex',
    flexDirection: 'column',
    overflow: 'hidden',
    pageBreakInside: 'avoid',
  };

  // Build the QR code payload (e.g. tracking number + governorate + COD amount)
  const qrPayload = `TRACKING:${label.tracking_number}|COD:${label.cod_amount}|GOV:${label.governorate}|CITY:${label.city}|PHONE:${label.primary_phone}`;

  return (
    <div 
      className="label-card-print select-none font-sans relative text-black bg-white overflow-hidden" 
      style={labelStyle}
      dir="rtl"
    >
      {/* Watermark Background Logo */}
      <div 
        className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 pointer-events-none opacity-[0.06] flex items-center justify-center"
        style={{ width: '70mm', height: '70mm', zIndex: 0 }}
      >
        <img 
          src="/logo.jpg" 
          alt="Watermark Logo" 
          className="w-full h-full object-contain grayscale" 
        />
      </div>
      
      {/* 1. TOP HEADER ROW (Logo, Barcode, QR Code) */}
      <div className="grid grid-cols-12 border-b border-black h-[22%]">
        
        {/* Logo (Left RTL) */}
        <div className="col-span-3 flex flex-col items-center justify-center border-l border-black bg-slate-50 p-1">
          <span className="text-lg font-black tracking-tighter text-black">فَلْكُون</span>
          <span className="text-[9px] font-bold text-slate-500 uppercase tracking-widest leading-none">FALCON</span>
        </div>

        {/* Barcode & Tracking Number (Center) */}
        <div className="col-span-6 flex flex-col items-center justify-center border-l border-black px-2 py-0.5">
          <Barcode value={label.tracking_number} height={isLayout3 ? 24 : 35} width={1.5} />
          <span className="text-[10px] font-mono font-bold mt-0.5">{label.tracking_number}</span>
        </div>

        {/* QR Code (Right RTL) */}
        <div className="col-span-3 flex items-center justify-center p-1 bg-white">
          <QRCodeComponent value={qrPayload} size={isLayout3 ? 42 : 55} />
        </div>
      </div>

      {/* 2. SECOND ROW (Shipper, Store Info, Product Type) */}
      <div className="grid grid-cols-12 border-b border-black text-[9px] font-bold h-[9%] bg-slate-50/50">
        <div className="col-span-4 flex items-center pr-2 border-l border-black">
          <span className="text-slate-500 ml-1">الراسل (Shipper):</span>
          <span>{label.shipper_id}</span>
        </div>
        <div className="col-span-5 flex items-center pr-2 border-l border-black">
          <span className="text-slate-500 ml-1">المتجر:</span>
          <span className="truncate">{label.store_name}</span>
        </div>
        <div className="col-span-3 flex items-center pr-2 justify-center">
          <span className="text-slate-500 ml-1">المنتج:</span>
          <span>{label.product_type}</span>
        </div>
      </div>

      {/* 3. MIDDLE BODY ROW (Address Block & Customer Details) */}
      <div className="grid grid-cols-12 flex-grow h-[47%]">
        
        {/* Address and Consignee Block (8/12 width) */}
        <div className="col-span-8 flex flex-col border-l border-black p-1.5 justify-between">
          <div>
            {/* Governorate & City header */}
            <div className="flex items-center gap-2 mb-1">
              <span className="px-2 py-0.5 bg-black text-white text-xs font-black rounded">
                {label.governorate}
              </span>
              <span className="text-[10px] font-black border-b border-black pb-0.5">
                {label.city}
              </span>
            </div>

            {/* Address */}
            <div 
              className="text-[9px] leading-tight mt-1 font-bold text-slate-800 break-words overflow-hidden"
              style={{
                display: '-webkit-box',
                WebkitLineClamp: isLayout3 ? 3 : 5,
                WebkitBoxOrient: 'vertical',
                maxHeight: isLayout3 ? '4.8em' : '8.5em',
              }}
            >
              <span className="text-slate-400">العنوان:</span> {label.address}
              {label.landmark && (
                <span className="block mt-0.5 text-slate-600 font-semibold bg-slate-100/50 px-1 rounded inline-block">
                  علامة مميزة: {label.landmark}
                </span>
              )}
            </div>
          </div>

          {/* Consignee Name */}
          <div className="mt-1 border-t border-slate-200 pt-1 flex items-baseline justify-between">
            <div className="text-[13px] font-black truncate">
              <span className="text-slate-400 font-medium ml-1 text-[10px]">المستلم:</span>
              {label.customer_name}
            </div>
          </div>
        </div>

        {/* Contact and Reference Info Block (4/12 width) */}
        <div className="col-span-4 flex flex-col justify-between p-1.5 bg-slate-50/20 text-[9px] font-bold">
          {/* Phones */}
          <div className="space-y-1">
            <span className="text-slate-400 block border-b border-slate-200 pb-0.5">تليفون العميل:</span>
            <span className="font-mono text-xs block font-extrabold select-all leading-none">{label.primary_phone}</span>
            {label.secondary_phone && (
              <span className="font-mono text-xs block font-extrabold select-all leading-none mt-1">{label.secondary_phone}</span>
            )}
          </div>

          {/* Ref */}
          <div className="border-t border-slate-200 pt-1">
            <span className="text-slate-400 block">مرجع الشحنة:</span>
            <span className="font-mono text-[9px] truncate block">{label.tracking_number}</span>
          </div>
        </div>
      </div>

      {/* 4. BOTTOM FOOTER ROW (COD, Weight, Pieces, Contents, Instructions) */}
      <div className="grid grid-cols-12 border-t border-black h-[22%] text-[9px] font-bold">
        
        {/* COD amount (Big Bold section) */}
        <div className="col-span-3 flex flex-col items-center justify-center bg-black text-white p-1">
          <span className="text-[8px] font-medium opacity-80 leading-none">مبلغ التحصيل (COD)</span>
          <span className="text-base font-black tracking-tight mt-0.5 leading-none">{label.cod_amount}</span>
          <span className="text-[8px] font-black leading-none mt-0.5">جنيه مصري</span>
        </div>

        {/* Weight & Pieces */}
        <div className="col-span-2 flex flex-col items-center justify-center border-l border-black p-1 text-center bg-slate-50">
          <div className="border-b border-slate-200 pb-0.5 w-full flex flex-col items-center">
            <span className="text-[8px] text-slate-400 leading-none">القطع</span>
            <span className="text-xs font-black mt-0.5 leading-none">{label.pieces}</span>
          </div>
          <div className="pt-0.5 w-full flex flex-col items-center">
            <span className="text-[8px] text-slate-400 leading-none">الوزن</span>
            <span className="text-xs font-black mt-0.5 leading-none">{label.weight} كجم</span>
          </div>
        </div>

        {/* Shipment contents */}
        <div className="col-span-3 flex flex-col justify-start border-l border-black p-1">
          <span className="text-[8px] text-slate-400">محتوى الشحنة:</span>
          <span className="text-[8px] leading-tight font-bold text-slate-700 mt-0.5 overflow-hidden line-clamp-2">{label.contents}</span>
        </div>

        {/* Delivery instructions */}
        <div className="col-span-4 flex flex-col justify-start p-1 bg-slate-50/50">
          <span className="text-[8px] text-slate-400">تعليمات التوصيل:</span>
          <span className="text-[8px] leading-tight font-extrabold text-black mt-0.5 overflow-hidden line-clamp-2">
            {label.instructions || 'الرجاء الاتصال والتسليم للعميل باليد.'}
          </span>
        </div>
      </div>

    </div>
  );
};
