import { createStyles, UnstyledButton } from '@mantine/core';
import { IconProp } from '@fortawesome/fontawesome-svg-core';
import LibIcon from '../../../../components/LibIcon';

interface Props {
  icon: IconProp;
  canClose?: boolean;
  iconSize: number;
  handleClick: () => void;
}

const useStyles = createStyles((theme, params: { canClose?: boolean }) => ({
  button: {
    display: 'flex',
    alignItems: 'center',
    justifyContent: 'center',
    alignSelf: 'stretch',
    width: 48,
    flexShrink: 0,
    color: params.canClose === false ? theme.colors.dark[4] : theme.white,
    cursor: params.canClose === false ? 'not-allowed' : 'pointer',
    '&:hover': params.canClose === false ? undefined : { backgroundColor: theme.white, color: theme.colors.dark[9] },
  },
}));

const HeaderButton: React.FC<Props> = ({ icon, canClose, iconSize, handleClick }) => {
  const { classes } = useStyles({ canClose });

  return (
    <UnstyledButton className={classes.button} disabled={canClose === false} onClick={handleClick}>
      <LibIcon icon={icon} fontSize={iconSize} fixedWidth />
    </UnstyledButton>
  );
};

export default HeaderButton;
