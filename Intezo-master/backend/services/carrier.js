// Pakistani Carrier Prefix Mapping
const PAK_CARRIERS = {
  '300': 'jazz',
  '301': 'jazz',
  '302': 'jazz',
  '303': 'jazz',
  '304': 'zong',
  '305': 'zong',
  '306': 'zong',
  '307': 'ufone',
  '308': 'ufone',
  '309': 'telenor',
  '331': 'zong',  // Add these new mappings
  '332': 'jazz',
  '333': 'ufone',
  '334': 'ufone',  // This covers your 03342407631 number
  '335': 'jazz',
  '336': 'telenor',
  '337': 'ufone',
  '338': 'warid',
  '339': 'telenor'
};

export const detectCarrier = (phone) => {
  const normalized = phone.replace(/^\+92|^92|^0|\s/g, '').substring(0, 3);
  return PAK_CARRIERS[normalized] || 'other';
};