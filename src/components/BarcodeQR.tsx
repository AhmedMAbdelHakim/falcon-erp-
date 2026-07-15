import React, { useEffect, useRef } from 'react';
import JsBarcode from 'jsbarcode';
import { QRCodeSVG } from 'qrcode.react';

interface BarcodeProps {
  value: string;
  height?: number;
  width?: number;
  displayValue?: boolean;
}

export const Barcode: React.FC<BarcodeProps> = ({
  value,
  height = 35,
  width = 1.6,
  displayValue = false,
}) => {
  const barcodeRef = useRef<SVGSVGElement>(null);

  useEffect(() => {
    if (barcodeRef.current && value) {
      try {
        JsBarcode(barcodeRef.current, value, {
          format: 'CODE128',
          width: width,
          height: height,
          displayValue: displayValue,
          margin: 0,
          background: 'transparent',
          lineColor: '#000000',
        });
        barcodeRef.current.setAttribute('shape-rendering', 'crispEdges');
      } catch (err) {
        console.error('Failed to generate barcode:', err);
      }
    }
  }, [value, height, width, displayValue]);

  return (
    <div className="flex flex-col items-center justify-center w-full">
      <svg ref={barcodeRef} className="max-w-full h-auto" />
    </div>
  );
};

interface QRCodeProps {
  value: string;
  size?: number;
}

export const QRCodeComponent: React.FC<QRCodeProps> = ({ value, size = 64 }) => {
  if (!value) return null;

  return (
    <div className="flex items-center justify-center p-0.5 bg-white border border-black">
      <QRCodeSVG
        value={value}
        size={size}
        level="M"
        bgColor="#FFFFFF"
        fgColor="#000000"
        includeMargin={false}
        style={{ shapeRendering: 'crispEdges' }}
      />
    </div>
  );
};
