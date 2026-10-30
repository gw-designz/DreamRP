import { Checkbox } from '@mantine/core';

const CustomCheckbox: React.FC<{ checked: boolean }> = ({ checked }) => {
  return <Checkbox checked={checked} readOnly size="md" />;
};

export default CustomCheckbox;
